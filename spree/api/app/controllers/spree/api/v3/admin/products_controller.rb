module Spree
  module Api
    module V3
      module Admin
        class ProductsController < ResourceController
          # Sort values that require special scopes
          CUSTOM_SORT_SCOPES = {
            'price' => :ascend_by_price,
            '-price' => :descend_by_price,
            'best_selling' => :by_best_selling
          }.freeze

          # POST /api/v3/admin/products
          def create
            authorize!(:create, Spree::Product)

            result = Spree.product_create_service.call(
              store: current_store,
              params: product_service_params
            )

            if result.success?
              @resource = result.value[:product]
              render json: serialize_resource(@resource), status: :created
            else
              render_result_error(result)
            end
          end

          # PATCH /api/v3/admin/products/:id
          def update
            result = Spree.product_update_service.call(
              product: @resource,
              store: current_store,
              params: product_service_params
            )

            if result.success?
              @resource = result.value[:product]
              render json: serialize_resource(@resource)
            else
              render_result_error(result)
            end
          end

          # POST /api/v3/admin/products/:id/clone
          def clone
            @resource = find_resource
            authorize!(:create, @resource)

            result = @resource.duplicate
            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_service_error(result.error)
            end
          end

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.admin_product_serializer
          end

          def scope_includes
            [
              thumbnail: [attachment_attachment: :blob],
              master: [:prices, stock_items: :stock_location],
              variants: [:prices, stock_items: :stock_location]
            ]
          end

          def collection_distinct?
            !custom_sort_requested?
          end

          def apply_collection_sort(collection)
            sort_value = sort_param
            return collection unless sort_value.present?

            scope_method = CUSTOM_SORT_SCOPES[sort_value]
            return collection unless scope_method

            sorted = collection.reorder(nil)
            sort_value == 'best_selling' ? sorted.distinct(false).send(scope_method) : sorted.send(scope_method)
          end

          def ransack_params
            rp = super

            if sort_param.present? && CUSTOM_SORT_SCOPES.key?(sort_param)
              rp = rp.is_a?(Hash) ? rp.dup : rp.to_unsafe_h
              rp.delete('s')
            end

            rp
          end

          private

          # Render error from ServiceModule::Result, extracting ActiveModel::Errors
          # from the ResultError wrapper to get proper validation_error responses.
          def render_result_error(result)
            error = result.error
            errors = error.respond_to?(:value) ? error.value : error

            if errors.is_a?(ActiveModel::Errors)
              render_validation_error(errors)
            else
              render_service_error(error)
            end
          end

          def custom_sort_requested?
            CUSTOM_SORT_SCOPES.key?(sort_param)
          end

          def product_service_params
            params.permit(
              *Spree::PermittedAttributes.product_attributes,
              tags: [],
              variants: [
                :sku, :barcode, :price, :compare_at_price,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :tax_category_id,
                :option_type, :option_value, :position,
                prices: [:amount, :compare_at_amount, :currency]
              ]
            )
          end
        end
      end
    end
  end
end
