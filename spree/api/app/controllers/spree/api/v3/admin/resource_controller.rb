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
        end
      end
    end
  end
end
