module Spree
  module Products
    # @deprecated Renamed to AutoMatchCollectionsJob in 6.0 (behavior moved to
    #   collections). Subclasses it so jobs enqueued under the old class name still
    #   deserialize and run; removed in 6.1.
    class AutoMatchTaxonsJob < AutoMatchCollectionsJob
      def perform(product_id)
        Spree::Deprecation.warn('Spree::Products::AutoMatchTaxonsJob is deprecated and will be removed in Spree 6.1. Use Spree::Products::AutoMatchCollectionsJob instead.')
        super
      end
    end
  end
end
