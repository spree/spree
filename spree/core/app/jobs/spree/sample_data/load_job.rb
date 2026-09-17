module Spree
  module SampleData
    # Loads the demo catalog, customers and orders in the background. Enqueued
    # by first-run setup when the merchant ticks "load sample data": the
    # loader needs an admin to own its imports and downloads product images,
    # so it can neither run before setup nor inside the setup request.
    class LoadJob < Spree::BaseJob
      def perform
        Spree::SampleData::Loader.call
      end
    end
  end
end
