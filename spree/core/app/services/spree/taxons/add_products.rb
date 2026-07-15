module Spree
  module Taxons
    # @deprecated Renamed to Spree::Categories::AddProducts in 6.0. This shim keeps
    #   the old `taxons:` keyword working by delegating to the renamed service;
    #   removed in 6.1.
    class AddProducts
      prepend Spree::ServiceModule::Base

      # @param taxons [Array<Spree::Category>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(taxons:, products:)
        Spree::Deprecation.warn('Spree::Taxons::AddProducts is deprecated and will be removed in Spree 6.1. Use Spree::Categories::AddProducts instead.')
        Spree::Categories::AddProducts.call(categories: taxons, products: products)
      end
    end
  end
end
