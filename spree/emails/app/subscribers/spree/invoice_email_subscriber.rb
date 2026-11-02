# frozen_string_literal: true

module Spree
  # Emails a new invoice to its recipient when the store sends invoices, and
  # sends any invoice again when someone asks.
  class InvoiceEmailSubscriber < Spree::Subscriber
    subscribes_to 'invoice.created', 'invoice.delivery_requested'

    on 'invoice.created', :deliver_new
    on 'invoice.delivery_requested', :deliver_again

    # The invoice email setting is the buyer's: a store whose own system sends
    # buyer invoices still sends sellers their commission invoices.
    def deliver_new(event)
      invoice = find_invoice(event)
      return if invoice.nil? || !audience_emails_enabled?(invoice)
      return if invoice.order && !invoice.store.prefers_send_invoice_email?

      deliver(invoice, resend: false)
    end

    # Whatever the automatic invoice email setting says, but never past a
    # store that turned this audience's emails off.
    def deliver_again(event)
      invoice = find_invoice(event)
      deliver(invoice, resend: true) if invoice && audience_emails_enabled?(invoice)
    end

    private

    def find_invoice(event)
      Spree::Invoice.find_by_prefix_id(event.payload['id'])
    end

    def audience_emails_enabled?(invoice)
      if invoice.order
        invoice.store.prefers_send_consumer_transactional_emails?
      else
        invoice.store.prefers_send_seller_transactional_emails?
      end
    end

    def deliver(invoice, resend:)
      return if invoice.recipient_email.blank?

      if invoice.order
        InvoiceMailer.invoice_email(invoice.id, resend).deliver_later
      else
        InvoiceMailer.commission_invoice_email(invoice.id, resend).deliver_later
      end
    end
  end
end
