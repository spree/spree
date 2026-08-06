module Spree
  module Api
    module V3
      module Admin
        # Product types are back-office only — there is no Store API counterpart.
        #
        # Editing a type never mutates existing products: option types and
        # categories seed onto products when the type is attached, and the
        # custom field list is read live when a product form renders. The one
        # path from a type edit to existing products is `apply_to_products`.
        class ProductTypesController < ResourceController
          scoped_resource :products

          # Backfills this type's option types and categories onto the products
          # that already carry it. Additive and idempotent — nothing is removed.
          def apply_to_products
            @resource = find_resource
            authorize!(:update, @resource)

            Spree::ProductTypes::ApplyToProductsJob.perform_later(@resource.id)

            render json: { products_count: @resource.products_count.to_i }, status: :accepted
          end

          protected

          def model_class
            Spree::ProductType
          end

          def serializer_class
            Spree.api.admin_product_type_serializer
          end

          def collection_includes
            [:option_types, :categories, { product_type_custom_field_definitions: :custom_field_definition }]
          end

          def permitted_params
            attrs = params.permit(
              :name,
              fulfillment_types: [],
              option_type_ids: [],
              category_ids: [],
              custom_field_definitions: [:id, :required, :sort_order]
            )
            reject_foreign_associations(attrs)
          end

          # `category_ids=` resolves prefixed ids with no store scoping, so a
          # type in this store could otherwise be pointed at another store's
          # categories. (OptionType is global — nothing to scope there.)
          def reject_foreign_associations(attrs)
            if attrs[:category_ids].present?
              resolved = Array(attrs[:category_ids]).filter_map { |id| Spree::Category.find_by_prefix_id(id)&.id }
              attrs[:category_ids] = current_store.categories.where(id: resolved).pluck(:id)
            end

            attrs
          end
        end
      end
    end
  end
end
