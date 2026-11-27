module Spree
  module Api
    module V3
      module Store
        # The collections a shopper on this channel may see. Every Store API
        # read of collections goes through it, so a visibility rule added
        # here reaches the collection endpoints, listings, filters and search.
        module StorefrontCollections
          extend ActiveSupport::Concern

          private

          def storefront_collections
            current_store.collections.published_on(Spree::Current.channel)
          end
        end
      end
    end
  end
end
