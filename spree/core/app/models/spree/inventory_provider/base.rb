module Spree
  module InventoryProvider
    # Contract for inventory sources — what answers "how many of this variant
    # exist, and where".
    #
    # A provider returns {Spree::StockLevel} rows: {Internal} the persisted
    # ones, an external provider **unsaved, readonly** instances carrying the
    # remote system's counts. {Spree::Stock::Quantifier} does the arithmetic
    # over whatever rows it is handed, so backorder limits, preorders and local
    # checkout reservations behave the same either way — an external system
    # does not know about our carts, so those holds must stay local.
    #
    # **Only decision points consult a provider.** Add-to-cart, taking a
    # reservation and completing checkout ask; listings, product pages and
    # search read the local snapshot the sync feed maintains. A provider on the
    # read path would mean one remote call per product tile, and would take the
    # storefront down with the remote system.
    class Base
      include Spree::IntegrationBackedProvider

      # @param variant [Spree::Variant]
      # @param stock_location [Spree::StockLocation, nil] narrows to one location
      # @return [Enumerable<Spree::StockLevel>]
      def stock_levels_for(_variant, stock_location: nil)
        raise NotImplementedError, "#{self.class} must implement #stock_levels_for"
      end

    end
  end
end
