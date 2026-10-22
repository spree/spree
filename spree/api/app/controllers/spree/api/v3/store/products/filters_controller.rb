module Spree
  module Api
    module V3
      module Store
        module Products
          class FiltersController < Store::BaseController
            include Spree::Api::V3::Store::SearchProviderSupport
            include Spree::Api::V3::Store::StorefrontProducts

            def index
              json = Rails.cache.fetch(filters_cache_key, expires_in: 15.minutes) do
                result = search_provider.filters(
                  scope: filters_scope,
                  query: search_query,
                  filters: (search_filters || {}).merge('_category' => category, '_collection' => collection)
                )

                serialize_resource(result)
              end

              render json: json
            end

            protected

            def serializer_class
              Spree.api.product_filters_serializer
            end

            private

            def filters_cache_key
              products_table = Spree::Product.table_name
              stats = storefront_products.
                        pick(Arel.sql("MAX(#{products_table}.updated_at)"), Arel.sql("COUNT(DISTINCT #{products_table}.id)"))
              max_updated = stats&.first&.to_i
              product_count = stats&.last || 0

              parts = [
                'spree/api/v3/store/filters',
                current_store.id,
                current_currency,
                current_locale,
                (hide_prices? ? 'prices_hidden' : nil),
                buyer_catalog_fragment,
                category&.cache_key_with_version,
                collection&.cache_key_with_version,
                search_query,
                search_filters&.sort_by(&:first)&.to_json,
                max_updated,
                product_count,
                search_provider.custom_field_schema.schema_version
              ]

              parts.compact.join('/')
            end

            # The buyer's catalogs partition the cache: a facet payload built
            # for one assortment must not be served to a buyer who sees
            # another, or it would describe products their listing never
            # returns.
            def buyer_catalog_fragment
              catalogs = Spree::Catalog.for_buyer(store: current_store, customer: current_user, channel: current_channel)
              return if catalogs.empty?

              "catalogs-#{catalogs.map(&:id).sort.join('-')}"
            end

            def filters_scope
              # Mirror ProductsController#scope so facet counts describe the
              # same product set the listing returns (coming-soon pre-orders
              # included) — narrowed to the buyer's catalogs like the listing.
              scope = storefront_products
              scope = scope.in_category(category) if category.present?
              scope = scope.in_collection(collection) if collection.present?
              scope
            end

            def category
              category_id = params[:category_id]
              @category ||= category_id.present? ? current_store.categories.find_by_param(category_id) : nil
            end

            def collection
              collection_id = params[:collection_id]
              @collection ||= collection_id.present? ? current_store.collections.find_by_param(collection_id) : nil
            end
          end
        end
      end
    end
  end
end
