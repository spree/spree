module Spree
  module Api
    module V3
      module Store
        module Collections
          # Dedicated collection PLP. Reuses the ProductsController search flow;
          # the collection is applied as an `in_collection` filter (not an AR
          # pre-scope, so Meilisearch's own filtering/counting/pagination works),
          # and the collection's sort_order is the default when the request omits `sort`.
          class ProductsController < Spree::Api::V3::Store::ProductsController
            include Spree::Api::V3::Store::PermalinkLookup
            include Spree::Api::V3::Store::StorefrontCollections

            protected

            def collection
              return @collection if @collection.present?

              result = search_provider.search_and_filter(
                scope: scope.includes(collection_includes).preload_associations_lazily,
                query: search_query,
                filters: (search_filters || {}).merge('in_collection' => current_collection.prefixed_id),
                sort: sort_param.presence || collection_default_sort,
                page: page,
                limit: limit
              )

              @pagy = result.pagy
              @collection = result.products
            end

            private

            # The collection's sort_order rendered in the API sort format
            # (e.g. 'price asc' -> 'price') — the PLP default when `sort` is omitted.
            def collection_default_sort
              sort_order = current_collection.sort_order
              return sort_order unless sort_order.to_s.include?(' ')

              field, direction = sort_order.split(' ', 2)
              direction == 'desc' ? "-#{field}" : field
            end

            # The same published-on-this-channel collections the collection
            # endpoints serve, so an unpublished collection's listing is a 404.
            def current_collection
              @current_collection ||= find_by_id_or_permalink!(
                storefront_collections, params[:collection_id]
              )
            end
          end
        end
      end
    end
  end
end
