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

          # The join tables, not the targets — the serializer reports association
          # ids, so loading the option types and categories themselves would pay
          # for records nothing reads.
          def collection_includes
            [
              :option_type_product_types,
              :product_type_categories,
              { product_type_custom_field_definitions: :custom_field_definition }
            ]
          end

          # Single-resource actions need the same eager-loading; without it every
          # custom field row re-queries its definition.
          def find_resource
            scope.includes(collection_includes).find_by_prefix_id!(params[:id])
          end

          def permitted_params
            attrs = params.permit(
              *model_additional_permitted_attributes,
              :name,
              :delivery_profile_id,
              option_type_ids: [],
              category_ids: [],
              custom_field_definitions: [:id, :required, :sort_order]
            )
            attrs = scope_delivery_profile(attrs)
            scope_category_ids(attrs)
          end

          # The template profile must belong to this store — a cross-store id
          # 404s instead of silently linking.
          def scope_delivery_profile(attrs)
            return attrs unless params.key?(:delivery_profile_id)

            attrs[:delivery_profile] = if params[:delivery_profile_id].present?
                                            current_store.delivery_profiles.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_profile_id])
                                          end
            attrs.except(:delivery_profile_id)
          end

          # `category_ids=` resolves prefixed ids with no store scoping, so a
          # type in this store could otherwise be pointed at another store's
          # categories. Mirrors ProductsController#apply_categories.
          # (OptionType is global — nothing to scope there.)
          def scope_category_ids(attrs)
            return attrs if attrs[:category_ids].blank?

            category_ids = decode_ids(attrs[:category_ids], Spree::Category)
            attrs[:category_ids] = current_store.categories.
                                   accessible_by(current_ability, :update).
                                   where(id: category_ids).pluck(:id)
            attrs
          end
        end
      end
    end
  end
end
