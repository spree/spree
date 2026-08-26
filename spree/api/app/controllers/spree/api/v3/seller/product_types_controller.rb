module Spree
  module Api
    module V3
      module Seller
        # The product types a seller may list against.
        #
        # Read only, and deliberately so: a type carries the custom fields a
        # seller fills in, so they have to see it, but what types the
        # marketplace offers is the operator's decision
        # (docs/plans/6.0-seller-product-submission.md).
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
