module Spree
  module Api
    module V3
      module Store
        # The categories and collections a shopper on this channel may see.
        # Every Store API read of either goes through here, so a visibility
        # rule added here reaches their endpoints, listings, filters and search.
        module StorefrontVisibility
          extend ActiveSupport::Concern

          private

          # Hiding a category hides its subcategories too (Spree::Category.published_on).
          def storefront_categories
            current_store.categories.published_on(Spree::Current.channel)
          end

          def storefront_collections
            current_store.collections.published_on(Spree::Current.channel)
          end
        end
      end
    end
  end
end
