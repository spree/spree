module Spree
  module Imports
    class AssignTagsJob < Spree::Imports::BaseJob
      def perform(product_id, tags)
        product = Spree::Product.find(product_id)

        # Saving the product validates its translated attributes. ActiveJob
        # restores the enqueuing locale, but not the content locale, so in a
        # store whose default locale is not the application's, the product's
        # base-column name would be read as a missing translation and fail
        # the name presence check.
        with_store_content_locale(product.store) do
          product.tag_list = tags
          product.save!
        end
      end
    end
  end
end
