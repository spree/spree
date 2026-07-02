module Spree
  module Api
    module V3
      module Store
        # Mirrors Store::BaseController's concerns. Both classes anchor parallel
        # inheritance branches (V3::BaseController vs V3::ResourceController);
        # any concern added here MUST also be added to Store::BaseController.
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::ChannelResolution
          include Spree::Api::V3::StorefrontGating

          protected

          def authenticate_request!
            authenticate_api_key!
          end
        end
      end
    end
  end
end
