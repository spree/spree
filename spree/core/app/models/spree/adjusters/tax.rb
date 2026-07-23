module Spree
  module Adjusters
    # The tax pass of the recalculation pipeline. Runs order-scoped — a
    # single TaxRate.adjust call matches rates for the order's tax zone once
    # and refreshes every adjustable's TaxLines (per-adjustable delegation
    # would re-run zone matching N times and break the pre_tax_amount
    # bookkeeping for items without applicable rates).
    #
    # Interim: 6.0-tax-provider.md replaces these internals with the
    # configured tax provider.
    class Tax < Base
      self.type = :tax

      def self.adjust_all(order, adjustables)
        Spree::TaxRate.adjust(order, adjustables)
      end
    end
  end
end
