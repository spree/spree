module Spree
  module Api
    module V3
      module Store
        class CartsController < Store::ResourceController
          prepend_before_action :require_authentication!

          protected

          def set_parent
            @parent = current_user
          end

          def parent_association
            :carts
          end

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.cart_serializer
          end

          def apply_collection_sort(collection)
            collection.order(updated_at: :desc)
          end
        end
      end
    end
  end
end
