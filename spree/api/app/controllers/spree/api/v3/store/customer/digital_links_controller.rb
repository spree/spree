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

            # The `digital_links` association reaches links through orders and
            # line items, so it carries a DISTINCT and inherits an ORDER BY on
            # the line items' table. PostgreSQL rejects DISTINCT combined with
            # an ORDER BY column outside the select list, so reorder by the
            # links' own table — SQLite tolerates the inherited order, so this
            # only surfaces on a real deployment.
            def scope
              super.where(spree_orders: { store_id: current_store.id })
                   .reorder("#{Spree::DigitalLink.table_name}.created_at": :desc)
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
