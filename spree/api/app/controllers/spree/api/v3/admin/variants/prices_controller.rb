module Spree
  module Api
    module V3
      module Admin
        module Variants
          class PricesController < ResourceController
            protected

            def model_class
              Spree::Price
            end

            def serializer_class
              Spree.api.admin_price_serializer
            end

            def set_parent
              @parent = current_store.variants.find_by_prefix_id!(params[:variant_id])
              authorize!(:show, @parent.product)
            end

            def parent_association
              :prices
            end
          end
        end
      end
    end
  end
end
