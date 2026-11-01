module Spree
  # Sends an invoice, receipt or credit note with its PDF attached
  # (docs/plans/6.1-invoices-and-receipts.md): to the order's buyer, or for a
  # commission invoice to the seller. Records on the invoice that it was sent.
  class InvoiceMailer < BaseMailer
    after_deliver :mark_invoice_sent

    # @param invoice [Spree::Invoice, Integer]
    # @param resend [Boolean]
    def invoice_email(invoice, resend = false)
      load_invoice(invoice)
      @order = @invoice.order

      with_store_locale(current_store, @order.locale) do
        attach_invoice_file
        mail_template(
          {
            invoice: email_data(@invoice, Spree::Emails::InvoiceSerializer),
            order: email_data(@order, Spree::Emails::OrderSerializer),
            resend: resend
          },
          to: @order.email, store_url: current_store.storefront_url
        )
      end
    end

    # A commission invoice the marketplace issued the seller for a payout.
    # A seller email: never editable from the dashboard.
    #
    # @param invoice [Spree::Invoice, Integer]
    # @param resend [Boolean]
    def commission_invoice_email(invoice, resend = false)
      load_invoice(invoice)
      @seller = @invoice.seller_payout.seller

      with_store_locale(current_store) do
        attach_invoice_file
        mail_template(
          {
            invoice: email_data(@invoice, Spree::Emails::InvoiceSerializer),
            seller: email_data(@seller, Spree.api.seller_serializer),
            resend: resend
          },
          to: @invoice.recipient_email, store_url: current_store.storefront_url
        )
      end
    end

    private

    def load_invoice(invoice)
      @invoice = invoice.respond_to?(:id) ? invoice : Spree::Invoice.find(invoice)
      @current_store = @invoice.store
    end

    def email_currency
      @invoice&.currency || super
    end

    def attach_invoice_file
      attachments[@invoice.file.filename.to_s] = {
        mime_type: @invoice.file.content_type || 'application/pdf',
        content: @invoice.file.download
      }
    end

    def mark_invoice_sent
      @invoice&.mark_sent!
    end
  end
end
