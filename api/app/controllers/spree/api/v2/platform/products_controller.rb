module Spree
  module Api
    module V2
      module Platform
        class ProductsController < ResourceController
          include ::Spree::Api::V2::ProductListIncludes

          def translate
            return render_error_payload(I18n.t(:missing_provider, scope: 'spree.api.v2.translations')) unless automated_translations_service.enabled?

            result = automated_translations_service.call(
              product: resource,
              source_locale: current_store.default_locale,
              target_locales: current_store.supported_locales_list - [current_store.default_locale],
              skip_existing: true
            )

            if result.success?
              render_serialized_payload { { message: I18n.t(:success, scope: 'spree.api.v2.translations') } }
            else
              render_error_payload(result.value)
            end
          end

          private

          def model_class
            Spree::Product
          end

          def scope_includes
            product_list_includes
          end

          def spree_permitted_attributes
            super.push(:price)
          end

          def allowed_sort_attributes
            super.push(:available_on, :make_active_at)
          end

          def sorted_collection
            collection_sorter.new(collection, current_currency, params, allowed_sort_attributes).call
          end

          def collection_sorter
            Spree::Api::Dependencies.platform_products_sorter.constantize
          end

          def automated_translations_service
            Spree::Api::Dependencies.platform_products_generate_automated_translations.constantize
          end
        end
      end
    end
  end
end
