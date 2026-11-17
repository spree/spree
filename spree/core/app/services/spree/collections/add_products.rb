module Spree
  module Collections
    class AddProducts
      prepend Spree::ServiceModule::Base
      include Spree::ProductMemberships

      # Hand-picks the given products into the given collections, in bulk.
      # Adding is the later, explicit act, so it lifts an exclusion; a product
      # its rules already matched becomes hand-picked and keeps its position.
      #
      # @param collections [Array<Spree::Collection>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collections:, products:)
        return if collections.blank? || products.blank?

        pairs = { collection_id: collections.pluck(:id), product_id: products.pluck(:id) }

        ApplicationRecord.transaction do
          Spree::CollectionExclusion.where(pairs).delete_all
          add_memberships(collections, products)
          Spree::ProductCollection.hand_pick(collection_ids: pairs[:collection_id], product_ids: pairs[:product_id])
        end
        success(true)
      end

      private

      def membership_class = Spree::ProductCollection
      def group_class = Spree::Collection
      def membership_attributes = { source: 'manual' }

      def refresh_group_counters(collection_ids)
        Spree::Collection.reset_counters_in_bulk(collection_ids, :product_collections)
      end
    end
  end
end
