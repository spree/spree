module Spree
  module Api
    module V3
      module Seller
        # The categories a seller may file a product under.
        #
        # Read only: a seller chooses from what the marketplace offers, they do
        # not extend it (docs/plans/6.0-seller-product-submission.md). Scoped to
        # the store, which is derived from the seller.
        class CategoriesController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::Category
          end

          def serializer_class
            Spree.api.seller_category_serializer
          end

          def scope
            current_store.categories
          end
        end
      end
    end
  end
end
