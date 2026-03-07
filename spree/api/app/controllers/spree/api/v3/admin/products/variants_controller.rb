module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            # POST /api/v3/admin/products/:product_id/variants
            def create
              authorize!(:create, Spree::Variant)

              result = Spree.variant_create_service.call(
                product: @parent,
                params: variant_service_params
              )

              if result.success?
                @resource = result.value[:variant]
                render json: serialize_resource(@resource), status: :created
              else
                render_result_error(result)
              end
            end

            # PATCH /api/v3/admin/products/:product_id/variants/:id
            def update
              result = Spree.variant_update_service.call(
                variant: @resource,
                params: variant_service_params
              )

              if result.success?
                @resource = result.value[:variant]
                render json: serialize_resource(@resource)
              else
                render_result_error(result)
              end
            end

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
              :variants_including_master
            end

            def scope_includes
              [:prices, stock_items: :stock_location]
            end

            private

            def render_result_error(result)
              error = result.error
              errors = error.respond_to?(:value) ? error.value : error

              if errors.is_a?(ActiveModel::Errors)
                render_validation_error(errors)
              else
                render_service_error(error)
              end
            end

            def variant_service_params
              params.permit(
                :sku, :barcode, :price, :compare_at_price,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :tax_category_id,
                :option_type, :option_value, :position,
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
