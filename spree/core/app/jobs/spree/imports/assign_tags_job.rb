module Spree
  module Imports
    class AssignTagsJob < Spree::Imports::BaseJob
      def perform(product_id, tags)
        product = Spree::Product.find(product_id)

        # Saving the product validates its name, so it has to be read in the
        # store's content locale, as the import that created it wrote it. Run
        # later, or inline under a job wrapper that resets Spree::Current, the
        # content locale is the application's default while I18n still names
        # the store's: the name was then looked up as a missing translation,
        # read as blank, and the save failed in every store not written in the
        # application's default locale.
        with_store_content_locale(product.store) do
          # The tag parser drops blank names and keeps quoted names that
          # contain the delimiter whole, so the cell is passed as written.
          product.tag_list = tags
          product.save!
        end
      end
    end
  end
end
