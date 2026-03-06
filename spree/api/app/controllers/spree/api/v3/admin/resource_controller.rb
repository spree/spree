module Spree
  module Api
    module V3
      module Admin
        class ResourceController < Spree::Api::V3::ResourceController
          # Require secret API key for all Admin API requests
          before_action :authenticate_secret_key!

          protected

          # Override JWT audience to require admin tokens
          def expected_audience
            JWT_AUDIENCE_ADMIN
          end
        end
      end
    end
  end
end
