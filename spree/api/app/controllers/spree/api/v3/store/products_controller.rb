module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          # Sort values that require special scopes (not plain Ransack column sorts).
          CUSTOM_SORT_SCOPES = {
            'price asc' => :ascend_by_price,
            'price desc' => :descend_by_price,
            'best_selling' => :by_best_selling
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
              master: [:prices, stock_items: :stock_location],
              variants: [:prices, stock_items: :stock_location]
            ]
          end

          # Disable distinct when using custom sort scopes that add computed columns
          def collection_distinct?
            !custom_sort_requested?
          end

          # Applies sorting from the unified `sort` param.
          # Custom values ('price asc', 'best_selling') use product-specific scopes.
          # Standard Ransack values ('name asc', 'created_at desc') are passed to q[s].
          def apply_collection_sort(collection)
            sort_value = sort_param
            return collection unless sort_value.present?

            scope_method = CUSTOM_SORT_SCOPES[sort_value]
            return collection unless scope_method

            sorted = collection.reorder(nil)
            sort_value == 'best_selling' ? sorted.distinct(false).send(scope_method) : sorted.send(scope_method)
          end

          # Inject sort into ransack params when it's a standard Ransack sort
          def ransack_params
            rp = super
            sort_value = sort_param

            if sort_value.present? && !CUSTOM_SORT_SCOPES.key?(sort_value)
              rp = rp.respond_to?(:to_unsafe_h) ? rp.to_unsafe_h : rp.dup
              rp['s'] = sort_value
            end

            rp
          end

          private

          def sort_param
            params[:sort] || params.dig(:q, :s)
          end

          def custom_sort_requested?
            CUSTOM_SORT_SCOPES.key?(sort_param)
          end
        end
      end
    end
  end
end
