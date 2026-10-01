module Spree
  module Api
    module V3
      module Store
        # The products a storefront buyer may see: available now (or on
        # pre-order) in the current currency, narrowed to the catalogs their
        # company, customer group or channel resolve to. The product listing
        # reads through it, and so does anything else that accepts a product
        # or variant from the buyer, so an id cannot reach what the listing
        # would never show.
        module StorefrontProducts
          extend ActiveSupport::Concern

          private

          # @param base [ActiveRecord::Relation] products to narrow; the store's by default
          # @return [ActiveRecord::Relation<Spree::Product>]
          def storefront_products(base = current_store.products)
            Spree.products_for_context_service.call(
              store: current_store,
              channel: current_channel,
              customer: current_user,
              base: base.available(Time.current, Spree::Current.currency, include_preorderable: true)
            ).value
          end

          # @return [ActiveRecord::Relation<Spree::Variant>]
          def storefront_variants
            Spree::Variant.where(product_id: storefront_products.reorder(nil).select(Spree::Product.arel_table[:id]))
          end
        end
      end
    end
  end
end
