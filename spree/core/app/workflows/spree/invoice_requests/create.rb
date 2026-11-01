module Spree
  module InvoiceRequests
    # A buyer asking for an invoice on an order they hold
    # (docs/plans/6.1-invoices-and-receipts.md). Accepted within the store's
    # request window, once per order, and only while the order has no invoice.
    # Publishes `order.invoice_requested`, which is how whoever issues the
    # order's invoices — the merchant's ERP, a seller's software, or an
    # extension that generates them — learns it has one to make.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :invoice_request

      # @param order [Spree::Order]
      # @param customer [Object, nil] the signed-in buyer, nil for a guest
      # @param company_name [String, nil]
      # @param tax_id [String, nil]
      # @param billing_address_params [Hash, nil] where the invoice is addressed
      # @return [Spree::ServiceModule::Result] the request on success
      def perform(order:, customer: nil, company_name: nil, tax_id: nil, billing_address_params: nil)
        super

        step :ensure_requestable
        run_hooks :validate
        # The address is saved only once the request is allowed, and with it,
        # so a refused request leaves no personal data behind.
        ApplicationRecord.transaction do
          step :create_billing_address
          step :create_request
        end
        run_hooks :after_create

        invoice_request.publish_event('order.invoice_requested')
        success(invoice_request)
      end

      private

      def ensure_requestable
        failure(order, I18n.t('spree.invoice_requests.errors.not_placed')) unless order.status == 'placed'
        failure(order, I18n.t('spree.invoice_requests.errors.already_invoiced')) if order.invoices.invoices.exists?
        failure(order, I18n.t('spree.invoice_requests.errors.window_closed')) unless within_window?
      end

      # The window runs from when the buyer paid, falling back to when they
      # placed the order for one settled outside Spree. Creation times, because
      # a payment's `updated_at` moves with every refund and would reopen it.
      def within_window?
        days = order.store.preferred_invoice_request_window_days.to_i
        return false if days <= 0

        started_at = order.settlement_payments.completed.maximum(:created_at) || order.completed_at
        started_at.nil? || started_at >= days.days.ago
      end

      # Not added to the buyer's address book: it is where this one invoice is
      # addressed, nothing more.
      def create_billing_address
        return if billing_address_params.blank?

        result = Spree.address_create_service.call(address_params: billing_address_params.to_h.symbolize_keys)
        failure(result.value) unless result.success?
        @billing_address = result.value
      end

      def create_request
        @invoice_request = order.invoice_requests.new(
          store: order.store, customer: customer, company_name: company_name,
          tax_id: tax_id, billing_address: @billing_address
        )
        failure(invoice_request) unless invoice_request.save
      rescue ActiveRecord::RecordNotUnique
        failure(order, I18n.t('activerecord.errors.messages.invoice_request_already_open'))
      end
    end
  end
end
