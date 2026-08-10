module Spree
  module Api
    module V3
      module Store
        module Customer
          # Everything the signed-in customer can download, across all their
          # orders — the storefront's "my downloads" page. Individual links are
          # also nested in each order, but a library is unusable that way.
          class DigitalLinksController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::DigitalLink
            end

            def serializer_class
              Spree.api.digital_link_serializer
            end

            def scope
              Spree::DigitalLink.
                joins(line_item: :order).
                where(spree_orders: { id: current_user.orders.complete.where(store: current_store) }).
                order(created_at: :desc)
            end

            def scope_includes
              [digital_asset: { attachment_attachment: :blob }]
            end
          end
        end
      end
    end
  end
end
