module Spree
  module Invoices
    # Records an invoice, receipt or credit note on an order or a seller payout
    # (docs/plans/6.1-invoices-and-receipts.md). Uploads call it with
    # `source: 'uploaded'`; an extension that generates invoices calls it with
    # `source: 'generated'`, so both fulfil the order's open invoice request the
    # same way.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The invoice that was created, readable by hook handlers.
      attr_reader :invoice

      # @param parent [Spree::Order, Spree::SellerPayout]
      # @param attributes [Hash] kind, number, issued_on, totals, file (or file_signed_id)…
      # @param uploaded_by [Object, nil] the admin user, seller user or integration
      # @param source [String] uploaded | generated
      # @param issuer [Spree::Store, Spree::Seller, nil] who the caller issues as;
      #   refused when the parent is invoiced by someone else
      # @return [Spree::ServiceModule::Result] the invoice on success
      def perform(parent:, attributes:, uploaded_by: nil, source: 'uploaded', issuer: nil)
        super

        step :build_invoice
        step :ensure_issuer
        run_hooks :validate

        ApplicationRecord.transaction do
          # Serializes with a buyer's invoice request on the same order.
          parent.class.lock.find(parent.id) if parent.is_a?(Spree::Order)
          step :save_invoice
          step :fulfil_open_request
        end

        run_hooks :after_create
        success(invoice)
      end

      private

      def build_invoice
        @invoice = Spree::Invoice.new(attributes.to_h.symbolize_keys)
        invoice.assign_attributes(source: source, uploaded_by: uploaded_by)

        case parent
        when Spree::Order
          invoice.assign_attributes(order: parent, issuer: Spree::Invoice.issuer_for(parent))
        when Spree::SellerPayout
          invoice.assign_attributes(seller_payout: parent, issuer: parent.store)
        end
        invoice.store = parent.store
        invoice.currency ||= parent.currency
      end

      # A seller invoices their own orders; a platform-remitted seller's are
      # the store's, in the store's numbering.
      def ensure_issuer
        return if issuer.nil? || invoice.issuer == issuer

        failure(invoice, I18n.t('spree.invoices.errors.store_invoices_order'))
      end

      # The unique index is the guarantee: two uploads of one number racing
      # past the validation get the same answer the validation gives.
      def save_invoice
        failure(invoice) unless invoice.save
      rescue ActiveRecord::RecordNotUnique
        invoice.errors.add(:number, :taken)
        failure(invoice)
      end

      # Any invoice of kind `invoice` answers the buyer's request, however it
      # was made.
      def fulfil_open_request
        return unless invoice.kind == 'invoice' && invoice.order

        invoice.order.invoice_requests.open.first&.fulfill!(invoice)
      end
    end
  end
end
