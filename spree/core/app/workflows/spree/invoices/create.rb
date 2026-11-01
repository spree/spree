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
      # @return [Spree::ServiceModule::Result] the invoice on success
      def perform(parent:, attributes:, uploaded_by: nil, source: 'uploaded')
        super

        step :build_invoice
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_invoice
          step :fulfil_open_request
        end

        run_hooks :after_create
        success(invoice.reload)
      end

      private

      def build_invoice
        @invoice = Spree::Invoice.new(attributes.to_h.symbolize_keys)
        invoice.assign_attributes(source: source, uploaded_by: uploaded_by)

        case parent
        when Spree::Order
          invoice.assign_attributes(order: parent, store: parent.store, issuer: Spree::Invoice.issuer_for(parent))
          invoice.currency ||= parent.currency
        when Spree::SellerPayout
          invoice.assign_attributes(seller_payout: parent, store: parent.store, issuer: parent.store)
          invoice.currency ||= parent.currency
        end
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
