module Spree
  module Api
    module V3
      module Admin
        # Mirrors Admin::BaseController's concerns. Both classes anchor parallel
        # inheritance branches (V3::BaseController vs V3::ResourceController);
        # any concern added here MUST also be added to Admin::BaseController.
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::AdminAuthentication
          include Spree::Api::V3::ScopedAuthorization

          protected

          def authenticate_request!
            authenticate_admin!
          end

          # Render error from ServiceModule::Result, extracting ActiveModel::Errors
          # from the ResultError wrapper to get proper validation_error responses.
          def render_result_error(result)
            error = result.error
            errors = error.respond_to?(:value) ? error.value : error

            if errors.is_a?(ActiveModel::Errors)
              render_validation_error(errors)
            else
              render_service_error(error)
            end
          end

          def decode_ids(ids, klass)
            Array(ids).map do |id|
              Spree::PrefixedId.prefixed_id?(id) ? klass.find_by_param!(id).id : id
            end
          end

          def decode_prefixed_ids(ids)
            Array(ids).map do |id|
              Spree::PrefixedId.prefixed_id?(id) ? Spree::PrefixedId.decode_prefixed_id(id) : id
            end
          end

          # Returns +url+ only when it matches one of the store's configured
          # allowed origins — the gate for caller-provided URLs that later
          # surface outside the request (e.g. the results_url the import/export
          # done emails link back to). Anything else is silently dropped,
          # mirroring the password-reset redirect_url behavior: no configured
          # origins means no caller URLs are honored.
          # @return [String, nil]
          def validated_allowed_origin_url(url)
            return if url.blank?
            return unless current_store.allowed_origin?(url)

            url
          end

          # Parses a strictly-integer param, returning nil for missing/blank/
          # non-integer values (so callers can reject rather than coerce to 0).
          # @return [Integer, nil]
          def integer_param(name)
            value = params[name]
            Integer(value, exception: false) if value.is_a?(Integer) || value.to_s.match?(/\A-?\d+\z/)
          end

          # Renders a 422 for a missing/invalid +new_position+.
          def render_invalid_position
            render_error(
              code: ERROR_CODES[:validation_error],
              message: Spree.t('api.errors.invalid_position', default: 'new_position must be an integer'),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
