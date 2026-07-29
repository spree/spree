module Spree
  module TaxProvider
    # Contract for tax providers — the only sanctioned writers of
    # {Spree::TaxLine} rows. +estimate+ must use replace-all set semantics per
    # target item (delete the item's stale lines, insert fresh ones); that is
    # what keeps tax correct after address or item changes. Commit/void/refund
    # are lifecycle no-ops for providers without a remote ledger.
    class Base
      # Recomputes tax for the given items (defaults to all taxable items of
      # the owner: line items, fulfillments and fees).
      #
      # @param owner [Spree::Order, Spree::Cart]
      # @param items [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>, nil]
      def estimate(owner, items = nil)
        raise NotImplementedError, "Please implement 'estimate' in your tax provider: #{self.class.name}"
      end

      # Finalizes tax with the provider at completion (no-op by default).
      def commit(owner); end

      # Cancels a previously committed tax document (no-op by default).
      def void(owner); end

      # Reports a refund against committed tax (no-op by default).
      def refund(owner, amount); end

      # @return [Boolean] whether the owner is tax-exempt
      def exempt?(_owner)
        false
      end
    end
  end
end
