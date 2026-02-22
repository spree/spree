module Spree
  module Api
    module V3
      module Store
        class ResourceController < Spree::Api::V3::ResourceController
          # Require publishable API key for all Store API requests
          before_action :authenticate_api_key!
        end
      end
    end
  end
end
