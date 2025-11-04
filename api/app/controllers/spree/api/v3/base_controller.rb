module Spree
  module Api
    module V3
      class BaseController < ActionController::API
        include ActiveStorage::SetCurrent
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Core::ControllerHelpers::Locale
        include Spree::Core::ControllerHelpers::Currency
        include Spree::Api::V3::Authentication
        include Spree::Api::V3::ExpandableResources

        # Optional authentication by default
        before_action :authenticate_user

        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from CanCan::AccessDenied, with: :access_denied
        rescue_from Spree::Core::GatewayError, with: :gateway_error
        rescue_from ActionController::ParameterMissing, with: :error_during_processing
        rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
        rescue_from ArgumentError, with: :error_during_processing
        rescue_from ActionDispatch::Http::Parameters::ParseError, with: :error_during_processing

        protected

        # Override to use current_user from JWT authentication
        def spree_current_user
          current_user
        end

        alias try_spree_current_user spree_current_user

        # CanCanCan ability
        def current_ability
          @current_ability ||= Spree::Ability.new(current_user, ability_options)
        end

        def ability_options
          { store: current_store }
        end

        # Render error responses
        def render_errors(errors, status = :unprocessable_entity)
          json = if errors.is_a?(ActiveModel::Errors)
                   { error: errors.full_messages.to_sentence, errors: errors.messages }
                 elsif errors.is_a?(String)
                   { error: errors }
                 else
                   { error: errors.to_s }
                 end

          render json: json, status: status
        end

        # Error handlers
        def record_not_found(exception)
          Rails.error.report(exception, context: { user_id: current_user&.id }, source: 'spree.api.v3')
          render_errors(Spree.t(:resource_not_found, scope: 'api'), :not_found)
        end

        def access_denied(exception)
          Rails.error.report(exception, context: { user_id: current_user&.id }, source: 'spree.api.v3')
          render_errors(exception.message, :forbidden)
        end

        def gateway_error(exception)
          Rails.error.report(exception, context: { user_id: current_user&.id }, source: 'spree.api.v3')
          render_errors(exception.message, :unprocessable_entity)
        end

        def error_during_processing(exception)
          Rails.error.report(exception, context: { user_id: current_user&.id }, source: 'spree.api.v3')
          message = exception.respond_to?(:original_message) ? exception.original_message : exception.message
          render_errors(message, :bad_request)
        end

        def unprocessable_entity(exception)
          Rails.error.report(exception, context: { user_id: current_user&.id }, source: 'spree.api.v3')
          render_errors(exception.record.errors, :unprocessable_entity)
        end
      end
    end
  end
end
