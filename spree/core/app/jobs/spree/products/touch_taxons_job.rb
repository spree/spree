module Spree
  module Products
    # @deprecated Renamed to Spree::Products::TouchCategoriesJob in 6.0. Subclasses it
    #   so jobs enqueued under the old class name before the deploy still deserialize
    #   and run; removed in 6.1.
    class TouchTaxonsJob < TouchCategoriesJob
      def perform(*args)
        Spree::Deprecation.warn('Spree::Products::TouchTaxonsJob is deprecated and will be removed in Spree 6.1. Use Spree::Products::TouchCategoriesJob instead.')
        super
      end
    end
  end
end
