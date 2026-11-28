module Spree
  module Exports
    # Every invoice, receipt and credit note in the store, one per row — what
    # an accountant asks for at the end of a period.
    class Invoices < Spree::Export
      # Decided once, when the export is created: the file is shared by
      # everyone in the store who can read exports, so whoever reads it later
      # must hold what its creator held (see #additional_read_permission).
      preference :includes_commission_invoices, :boolean, default: false

      before_create do
        self.preferred_includes_commission_invoices = user.present? && current_ability.can?(:read, Spree::SellerPayout)
      end

      def self.required_scope
        :orders
      end

      def additional_read_permission
        'read_payouts' if preferred_includes_commission_invoices
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
        preferred_includes_commission_invoices ? super : super.where(seller_payout_id: nil)
      end
    end
  end
end
