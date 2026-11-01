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

      # Commission invoices belong to seller payouts, so only a creator known
      # to read payouts gets them. An export made with an API key records no
      # user, and so cannot show it may.
      def scope
        user.present? && current_ability.can?(:read, Spree::SellerPayout) ? super : super.where(seller_payout_id: nil)
      end
    end
  end
end
