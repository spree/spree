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

          # `digital_links` reaches links through line items, so the query
          # carries a DISTINCT and inherits an ORDER BY on the line items'
          # table. PostgreSQL rejects DISTINCT combined with an ORDER BY column
          # outside the select list, so reorder by the links' own table —
          # SQLite tolerates the inherited order, so this only surfaces on a
          # real deployment.
          def scope
            current_store.digital_links.reorder("#{Spree::DigitalLink.table_name}.created_at": :desc)
          end

          def scope_includes
            [:line_item, digital_asset: { attachment_attachment: :blob }]
          end
        end
      end
    end
  end
end
