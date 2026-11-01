module Spree
  module Exports
    # Every invoice, receipt and credit note in the store, one per row — what
    # an accountant asks for at the end of a period.
    class Invoices < Spree::Export
      def self.required_scope
        :orders
      end

      def scope_includes
        [:issuer, :order, :original_invoice, :seller_payout]
      end

      def csv_headers
        Spree::CSV::InvoicePresenter::HEADERS
      end

      # Commission invoices belong to seller payouts, so a creator who may not
      # read payouts gets the store's sales documents only.
      def scope
        user.present? && current_ability.cannot?(:read, Spree::SellerPayout) ? super.where(seller_payout_id: nil) : super
      end
    end
  end
end
