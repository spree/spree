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

          # PATCH /api/v3/admin/products/:id
          def update
            if @resource.update(update_params)
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
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
              variants: [:prices, stock_items: :stock_location],
              variants_including_master: [stock_items: :stock_location]
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

          def permitted_params
            params.permit(
              *Spree::PermittedAttributes.product_attributes,
              tags: [],
              variants: [
                :id, :sku, :barcode, :price, :compare_at_price,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :tax_category_id, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_items: [:stock_location_id, :count_on_hand, :backorderable]
              ]
            )
          end

          private

          def update_params
            p = permitted_params.to_h.with_indifferent_access

            if p.key?(:taxon_ids)
              other_store_taxon_ids = @resource.taxons
                                               .joins(:taxonomy)
                                               .where.not(spree_taxonomies: { store_id: current_store.id })
                                               .pluck(:id)
              p[:taxon_ids] = (Array(p[:taxon_ids]) + other_store_taxon_ids).uniq
            end

            p
          end

          def custom_sort_requested?
            CUSTOM_SORT_SCOPES.key?(sort_param)
          end
        end
      end
    end
  end
end
