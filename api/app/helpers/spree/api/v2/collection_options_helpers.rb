module Spree
  module Api
    module V2
      module CollectionOptionsHelpers
        def collection_links(collection)
          pagy_obj = collection.respond_to?(:pagy) ? collection.pagy : nil

          {
            self: request.original_url,
            next: pagination_url(pagy_obj&.next || pagy_obj&.last || 1),
            prev: pagination_url(pagy_obj&.prev || 1),
            last: pagination_url(pagy_obj&.last || 1),
            first: pagination_url(1)
          }
        end

        def collection_meta(collection)
          pagy_obj = collection.respond_to?(:pagy) ? collection.pagy : nil

          {
            count: collection.size,
            total_count: pagy_obj&.count || collection.size,
            total_pages: pagy_obj&.pages || 1
          }
        end

        # leaving this method in public scope so it's still possible to modify
        # those params to support non-standard non-JSON API parameters
        def collection_permitted_params
          params.permit(:format, :page, :per_page, :sort, :include, :locale, fields: {}, filter: {})
        end

        private

        def pagination_url(page)
          url_for(collection_permitted_params.merge(page: page))
        end

        def collection_options(collection)
          {
            links: collection_links(collection),
            meta: collection_meta(collection),
            include: resource_includes,
            fields: sparse_fields
          }
        end
      end
    end
  end
end
