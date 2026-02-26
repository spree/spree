module Spree
  module Api
    module V3
      module ErrorHandler
        extend ActiveSupport::Concern

        # Stripe-style error codes for consistent API error responses
        ERROR_CODES = {
          # Authentication & authorization errors
          authentication_required: 'authentication_required',
          authentication_failed: 'authentication_failed',
          access_denied: 'access_denied',
          invalid_token: 'invalid_token',
          invalid_provider: 'invalid_provider',

          # Resource errors
          record_not_found: 'record_not_found',
          resource_invalid: 'resource_invalid',

          # Order errors
          order_not_found: 'order_not_found',
          order_already_completed: 'order_already_completed',
          order_cannot_transition: 'order_cannot_transition',
          order_empty: 'order_empty',
          order_invalid_state: 'order_invalid_state',

          # Line item errors
          line_item_not_found: 'line_item_not_found',
          variant_not_found: 'variant_not_found',
          insufficient_stock: 'insufficient_stock',
          invalid_quantity: 'invalid_quantity',

          # Validation errors
          validation_error: 'validation_error',
          parameter_missing: 'parameter_missing',
          parameter_invalid: 'parameter_invalid',

          # Payment errors
          payment_failed: 'payment_failed',
          payment_processing_error: 'payment_processing_error',
          gateway_error: 'gateway_error',

          # Digital download errors
          attachment_missing: 'attachment_missing',
          download_unauthorized: 'download_unauthorized',
          digital_link_expired: 'digital_link_expired',
          download_limit_exceeded: 'download_limit_exceeded',

          # Rate limiting errors
          rate_limit_exceeded: 'rate_limit_exceeded',

          # Request errors
          request_too_large: 'request_too_large',

          # General errors
          processing_error: 'processing_error',
          invalid_request: 'invalid_request'
        }.freeze

        included do
          # Override base controller error handlers
          rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
          rescue_from CanCan::AccessDenied, with: :handle_access_denied
          rescue_from Spree::Core::GatewayError, with: :handle_gateway_error
          rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
          rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
          rescue_from ArgumentError, with: :handle_argument_error
          rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error
          rescue_from StateMachines::InvalidTransition, with: :handle_invalid_transition
        end

        protected

        # Main error rendering method with Stripe-style structure
        def render_error(code:, message:, status:, details: nil)
          error_response = {
            error: {
              code: code,
              message: message
            }
          }

          error_response[:error][:details] = details if details.present?

          render json: error_response, status: status
        end

        # Convenience method for validation errors with ActiveModel::Errors
        def render_validation_error(errors, code: ERROR_CODES[:validation_error])
          details = errors.is_a?(ActiveModel::Errors) ? format_validation_details(errors) : nil
          message = errors.is_a?(ActiveModel::Errors) ? errors.full_messages.to_sentence : errors.to_s

          render_error(
            code: code,
            message: message,
            status: :unprocessable_content,
            details: details
          )
        end

        # Convenience method for service result errors
        def render_service_error(error, code: ERROR_CODES[:processing_error], status: :unprocessable_content)
          if error.is_a?(ActiveModel::Errors)
            render_validation_error(error, code: code)
          elsif error.is_a?(String)
            render_error(code: code, message: error, status: status)
          else
            render_error(code: code, message: error.to_s, status: status)
          end
        end

        # Legacy support - redirect to new error handling
        def render_errors(errors, status = :unprocessable_content)
          code = infer_error_code(errors, status)

          if errors.is_a?(ActiveModel::Errors)
            render_validation_error(errors, code: code)
          else
            message = errors.is_a?(String) ? errors : errors.to_s
            render_error(code: code, message: message, status: status)
          end
        end

        # Exception handlers
        def handle_record_not_found(exception)
          code = determine_not_found_code(exception)
          message = generate_not_found_message(exception)

          render_error(
            code: code,
            message: message,
            status: :not_found
          )
        end

        def handle_access_denied(exception)
          render_error(
            code: ERROR_CODES[:access_denied],
            message: exception.message,
            status: :forbidden
          )
        end

        def handle_gateway_error(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          render_error(
            code: ERROR_CODES[:gateway_error],
            message: exception.message,
            status: :unprocessable_content
          )
        end

        def handle_parameter_missing(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          render_error(
            code: ERROR_CODES[:parameter_missing],
            message: exception.message,
            status: :bad_request
          )
        end

        def handle_record_invalid(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          render_validation_error(exception.record.errors)
        end

        def handle_argument_error(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          render_error(
            code: ERROR_CODES[:invalid_request],
            message: exception.message,
            status: :bad_request
          )
        end

        def handle_parse_error(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          message = exception.respond_to?(:original_message) ? exception.original_message : exception.message
          render_error(
            code: ERROR_CODES[:invalid_request],
            message: message,
            status: :bad_request
          )
        end

        def handle_invalid_transition(exception)
          Rails.error.report(exception, context: error_context, source: 'spree.api.v3')
          render_error(
            code: ERROR_CODES[:order_cannot_transition],
            message: exception.message,
            status: :unprocessable_content
          )
        end

        private

        # Format validation errors for details field
        def format_validation_details(errors)
          errors.messages.transform_values do |messages|
            messages.map { |msg| msg }
          end
        end

        # Infer error code from context
        def infer_error_code(errors, status)
          case status
          when :not_found
            ERROR_CODES[:record_not_found]
          when :forbidden
            ERROR_CODES[:access_denied]
          when :bad_request
            ERROR_CODES[:invalid_request]
          when :unprocessable_content
            errors.is_a?(ActiveModel::Errors) ? ERROR_CODES[:validation_error] : ERROR_CODES[:processing_error]
          else
            ERROR_CODES[:processing_error]
          end
        end

        # Determine specific not found code based on model
        def determine_not_found_code(exception)
          model_name = extract_model_name(exception)

          case model_name
          when 'order'
            ERROR_CODES[:order_not_found]
          when 'line_item'
            ERROR_CODES[:line_item_not_found]
          when 'variant'
            ERROR_CODES[:variant_not_found]
          else
            ERROR_CODES[:record_not_found]
          end
        end

        # Generate human-readable not found message
        def generate_not_found_message(exception)
          model_name = extract_model_name(exception)
          Spree.t(:record_not_found, scope: 'api', model: model_name&.humanize || 'record')
        end

        # Extract clean model name from exception
        def extract_model_name(exception)
          return nil unless exception.model

          # Remove Spree:: namespace and convert to underscore
          exception.model.to_s.demodulize.underscore
        end

        # Error reporting context
        def error_context
          {
            user_id: current_user&.id,
            store_id: current_store&.id,
            request_id: request.request_id
          }
        end
      end
    end
  end
end
