require 'spree/core/previews/preview_data'

# Preview Spree invoice emails at /rails/mailers/spree/invoice
class Spree::InvoicePreview < ActionMailer::Preview
  include Spree::PreviewData::LocaleParam

  def invoice_email
    invoice = Spree::Invoice.where.not(order_id: nil).last
    invoice.order.locale = locale if invoice && locale.present?
    Spree::InvoiceMailer.invoice_email(invoice)
  end

  def commission_invoice_email
    Spree::InvoiceMailer.commission_invoice_email(Spree::Invoice.where.not(seller_payout_id: nil).last)
  end
end
