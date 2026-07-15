module Spree
  module Products
    # @deprecated Automatic taxon matching moved to Spree::Collection in 6.0.
    #   Delegates to Spree::Products::AutoMatchCollections (same `product:` signature);
    #   removed in 6.1.
    class AutoMatchTaxons
      prepend ::Spree::ServiceModule::Base

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Base::Result]
      def call(product:)
        Spree::Deprecation.warn('Spree::Products::AutoMatchTaxons is deprecated and will be removed in Spree 6.1. Automatic membership moved to collections; use Spree::Products::AutoMatchCollections instead.')
        Spree::Products::AutoMatchCollections.call(product: product)
      end
    end
  end
end
