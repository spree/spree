module Spree
  module Api
    module V2
      module CollectionOptionsHelpers
        def collection_links(collection)
          {
            self: collection.current_page,
            next: collection.next_page || collection.total_pages,
            prev: collection.prev_page || 1,
            last: collection.total_pages,
            first: 1
          }
        end

        def collection_meta(collection)
          {
            count: collection.size,
            total_count: collection.total_count,
            total_pages: collection.total_pages
          }
        end
      end
    end
  end
end
