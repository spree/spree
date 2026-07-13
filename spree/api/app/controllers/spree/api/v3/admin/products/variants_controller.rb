module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            scoped_resource :products

            protected

            def model_class
              Spree::Variant
            end

            def serializer_class
              Spree.api.admin_variant_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end

            def parent_association
              :variants
            end

            def scope_includes
              [:prices, stock_items: :stock_location]
            end

            def permitted_params
              params.permit(
                :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit, :tax_category_id, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_items: [:stock_location_id, :count_on_hand, :backorderable]
              )
            end
          end
        end
      end
    end
  end
end
