module Spree
  module Api
    module V3
      module Store
        # The products a storefront buyer may see: available now (or on
        # pre-order) in the current currency, narrowed to the catalogs their
        # company, customer group or channel resolve to. The product listing
        # and wishlist items read through it, so an id cannot reach what the
        # listing would never show. Carts narrow through
        # {Spree::Cart#orderable_variants} instead, which asks the same
        # catalogs about the cart's own buyer and company.
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
            Spree::Variant.for_products(storefront_products)
          end
        end
      end
    end
  end
end
