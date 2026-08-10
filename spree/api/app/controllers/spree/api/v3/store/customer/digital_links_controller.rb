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

            def set_parent
              @parent = current_user
            end

            def parent_association
              :digital_links
            end

            def scope
              super.where(spree_orders: { store_id: current_store.id }).order(created_at: :desc)
            end

            # The serializer asks each link whether it is still authorizable,
            # which reads its order's store and its asset's limits — without
            # both preloads that is four queries per row.
            def scope_includes
              [{ line_item: :order }, { digital_asset: { attachment_attachment: :blob } }]
            end
          end
        end
      end
    end
  end
end
