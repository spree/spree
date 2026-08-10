module Spree
  module Api
    module V3
      module Admin
        class DigitalLinksController < ResourceController
          scoped_resource :orders

          before_action :set_resource, only: [:reset]

          # PATCH /api/v3/admin/digital_links/:id/reset
          #
          # Gives the customer their download allowance back and restarts the
          # expiry clock — the remedy when a download failed or a file was
          # replaced after they had used up their attempts.
          def reset
            @resource.reset!

            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::DigitalLink
          end

          def serializer_class
            Spree.api.admin_digital_link_serializer
          end

          def scope
            current_store.digital_links
          end

          def scope_includes
            [:line_item, digital_asset: { attachment_attachment: :blob }]
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action == :reset ? :update : action, resource)
          end
        end
      end
    end
  end
end
