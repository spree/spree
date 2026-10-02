module Spree
  module Collections
    class RemoveProducts
      prepend Spree::ServiceModule::Base
      include Spree::ProductMemberships

      # Removes the given products from the given collections and re-packs positions.
      #
      # @param collections [Array<Spree::Collection>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collections:, products:)
        return if collections.blank? || products.blank?

        remove_memberships(collections, products)
        success(true)
      end

      private

      def membership_class = Spree::ProductCollection
      def group_class = Spree::Collection

      def refresh_group_counters(collection_ids)
        collection_ids.each { |id| Spree::Collection.reset_counters(id, :product_collections) }
      end
    end
  end
end
