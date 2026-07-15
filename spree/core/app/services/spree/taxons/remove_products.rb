module Spree
  module Taxons
    # @deprecated Renamed to Spree::Categories::RemoveProducts in 6.0. This shim keeps
    #   the old `taxons:` keyword working by delegating to the renamed service;
    #   removed in 6.1.
    class RemoveProducts
      prepend Spree::ServiceModule::Base

      # @param taxons [Array<Spree::Category>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(taxons:, products:)
        Spree::Deprecation.warn('Spree::Taxons::RemoveProducts is deprecated and will be removed in Spree 6.1. Use Spree::Categories::RemoveProducts instead.')
        Spree::Categories::RemoveProducts.call(categories: taxons, products: products)
      end
    end
  end
end
