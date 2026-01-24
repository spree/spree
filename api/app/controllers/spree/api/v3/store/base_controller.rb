module Spree
  module Api
    module V3
      module Store
        class BaseController < Spree::Api::V3::BaseController
          # Require publishable API key for all Store API requests
          before_action :authenticate_api_key!

          protected

          # Store API always uses store context (not admin)
          def admin_context?
            false
          end
        end
      end
    end
  end
end
