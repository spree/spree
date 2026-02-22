module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          SORT_OPTIONS = {
            'price-low-to-high' => :ascend_by_price,
            'price-high-to-low' => :descend_by_price
          }.freeze

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.product_serializer
          end

          # Find product by slug or prefixed ID with i18n scope for SEO-friendly URLs
          # Falls back to default locale if product is not found in the current locale
          # @return [Spree::Product]
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('prod_')
              scope.find_by_prefix_id!(id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(slug: id) }
            end
          end

          def scope
            super.active(Spree::Current.currency)
          end

          # these scopes are not automatically picked by ar_lazy_preload gem and we need to explicitly include them
          def scope_includes
            [
              thumbnail: [attachment_attachment: :blob],
              master: [:prices],
              variants: [:prices]
            ]
          end

          # Disable distinct when using custom sort scopes that add computed columns
          def collection_distinct?
            !custom_sort_requested?
          end

          # Apply custom sorting scopes for price/best-selling
          def apply_collection_sort(collection)
            sort_by = params.dig(:q, :sort_by) || params[:sort_by]
            return collection unless sort_by.present?

            return collection.distinct(false).reorder(nil).by_best_selling if sort_by == 'best-selling'

            scope_method = SORT_OPTIONS[sort_by]
            return collection.reorder(nil).send(scope_method) if scope_method.present?

            collection
          end

          private

          def custom_sort_requested?
            sort_by = params.dig(:q, :sort_by) || params[:sort_by]
            SORT_OPTIONS.key?(sort_by)
          end
        end
      end
    end
  end
end
