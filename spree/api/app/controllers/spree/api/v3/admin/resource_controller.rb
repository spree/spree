module Spree
  module Api
    module V3
      module Admin
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::AdminAuthentication

          protected

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
        end
      end
    end
  end
end
