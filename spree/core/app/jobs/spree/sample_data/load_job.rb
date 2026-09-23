module Spree
  module SampleData
    # Loads the demo catalog, customers and orders in the background. Enqueued
    # by first-run setup when the merchant ticks "load sample data": the
    # loader needs an admin to own its imports and downloads product images,
    # so it can neither run before setup nor inside the setup request.
    class LoadJob < Spree::BaseJob
      # @param store_id [String, Integer, nil] the store to load into; the
      #   default store when omitted
      def perform(store_id = nil)
        return Spree::SampleData::Loader.call if store_id.nil?

        store = Spree::Store.find_by(id: store_id)
        Spree::SampleData::Loader.call(store: store) if store
      end
    end
  end
end
