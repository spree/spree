module Spree
  module Api
    module V3
      module Store
        module Products
          class FiltersController < Store::BaseController
            include Spree::Api::V3::Store::SearchProviderSupport

            def index
              json = Rails.cache.fetch(filters_cache_key, expires_in: 15.minutes) do
                result = search_provider.filters(
                  scope: filters_scope,
                  query: search_query,
                  filters: (search_filters || {}).merge('_category' => category)
                )

                {
                  filters: result.filters,
                  sort_options: result.sort_options,
                  default_sort: result.default_sort,
                  total_count: result.total_count
                }
              end

              render json: json
            end

            private

            def filters_cache_key
              products_table = Spree::Product.table_name
              stats = current_store.products.active(current_currency)
                        .pick(Arel.sql("MAX(#{products_table}.updated_at)"), Arel.sql("COUNT(DISTINCT #{products_table}.id)"))
              max_updated = stats&.first&.to_i
              product_count = stats&.last || 0

              parts = [
                'spree/api/v3/store/filters',
                current_store.id,
                current_currency,
                current_locale,
                category&.cache_key_with_version,
                search_query,
                search_filters&.sort_by(&:first)&.to_json,
                max_updated,
                product_count
              ]

              parts.compact.join('/')
            end

            def filters_scope
              scope = current_store.products.active(current_currency)
              scope = scope.in_category(category) if category.present?
              scope.accessible_by(current_ability, :show)
            end

            def category
              category_id = params[:category_id]
              @category ||= category_id.present? ? current_store.categories.find_by_param(category_id) : nil
            end
          end
        end
      end
    end
  end
end
