module Spree
  module Api
    module V3
      module Seller
        # The marketplace's shared catalog, as a seller browsing it sees it.
        #
        # The one seller-branch collection rooted in the STORE rather than in
        # `current_seller`: these products are the marketplace's own, and the
        # seller is looking for something to list against
        # (docs/plans/6.0-seller-master-catalog-listings.md).
        #
        # Read only, and narrowed three ways. Only first-party products — a
        # product another seller owns outright is theirs, not shared. Only
        # active ones — a draft or archived listing is not something to
        # compete on. And only ones the operator has opened, because a
        # curated marketplace opens the commodities and keeps its exclusives
        # (Decision 2).
        #
        # Serialized with the *store* serializers, so a seller sees rival
        # offers exactly as a shopper does — price, seller, stock — and never
        # a rival's cost price, customs data or warehouse (Decision 4).
        class MasterProductsController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::Product
          end

          # The public contract, not a seller-branch serializer of its own:
          # what one seller may know about another's offer is exactly what a
          # customer may know.
          def serializer_class
            Spree.api.product_serializer
          end

          # Overridden rather than given a `seller_association`: the anchor
          # roots every other collection on this branch in the seller's own
          # records, and this is the deliberate exception — the marketplace's
          # catalog is what a seller is searching.
          def scope
            base = current_store.products.active.for_seller(nil).open_to_sellers
            base = base.includes(scope_includes) if scope_includes.any?
            base.preload_associations_lazily.i18n
          end

          # `scope` already answers with the store's own products, so a
          # `resource_scope` rooted in the seller would find nothing.
          def resource_scope
            scope
          end

          def scope_includes
            [
              :seller,
              {
                primary_media: [attachment_attachment: :blob, poster_attachment: :blob],
                option_types: :option_values,
                variants: [:prices, :seller, stock_levels: [:stock_location, :active_stock_reservations]]
              }
            ]
          end

          # Reading the marketplace's catalog is part of maintaining a
          # catalog, which is what `read_products` grants. There is nothing
          # narrower to ask for: a seller who may not read products has no
          # use for a product picker.
          def authorize_resource!(resource = @resource, _action = action_name.to_sym)
            authorize!(:show, resource)
          end
        end
      end
    end
  end
end
