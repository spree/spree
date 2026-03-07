module Spree
  module Api
    module V3
      module Admin
        class ResourceController < Spree::Api::V3::ResourceController
          # Require secret API key for all Admin API requests
          before_action :authenticate_secret_key!

          # Admin API responses must never be cached
          after_action :set_no_store_cache

          protected

          # Override JWT audience to require admin tokens
          def expected_audience
            JWT_AUDIENCE_ADMIN
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

          private

          def set_no_store_cache
            response.headers['Cache-Control'] = 'private, no-store'
          end
        end
      end
    end
  end
end
