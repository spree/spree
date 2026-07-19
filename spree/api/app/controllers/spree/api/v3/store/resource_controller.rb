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

          # The inherited +set_parent+/+set_resource+ callbacks were registered
          # before the two concerns above, so they'd run resource lookups ahead
          # of channel resolution (wrong channel scoping for X-Spree-Channel /
          # key-bound requests) and ahead of the login gate (guests could probe
          # resource existence on a gated channel via 404s). Re-register them so
          # lookups always run inside the resolved channel context, behind the
          # gate.
          skip_before_action :set_parent
          skip_before_action :set_resource
          before_action :set_parent
          before_action :set_resource, only: [:show, :update, :destroy]

          protected

          def authenticate_request!
            authenticate_api_key!
          end
        end
      end
    end
  end
end
