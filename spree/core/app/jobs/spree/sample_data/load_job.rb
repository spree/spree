module Spree
  module SampleData
    # @deprecated First-run setup no longer queues this: the dashboard loads
    #   sample data through the Admin API. Kept so a job queued by an earlier
    #   release still runs; it loads nothing and will be removed in Spree 6.2.
    class LoadJob < Spree::BaseJob
      def perform(_store_id = nil)
        Spree::SampleData::Loader.call
      end
    end
  end
end
