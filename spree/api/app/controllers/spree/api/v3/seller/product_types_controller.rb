module Spree
  module Api
    module V3
      module Seller
        # The product types a seller may list against.
        #
        # Read only, and deliberately so: a seller picks a type because it is
        # the template that hands their product its option types and delivery
        # profile, but what types the marketplace offers is the operator's
        # decision (docs/plans/6.0-seller-product-submission.md, Decision 5).
        #
        # Types belong to the store rather than to a seller, so this is one of
        # the few seller collections not rooted in `current_seller` — the
        # store comes from the seller, which is what keeps it scoped.
        class ProductTypesController < Seller::ResourceController
          scoped_resource :product_types

          protected

          def model_class
            Spree::ProductType
          end

          def serializer_class
            Spree.api.seller_product_type_serializer
          end

          def scope
            current_store.product_types
          end
        end
      end
    end
  end
end
