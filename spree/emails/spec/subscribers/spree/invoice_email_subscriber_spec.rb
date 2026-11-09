require 'spec_helper'

describe Spree::InvoiceEmailSubscriber do
  let(:store) { create(:store) }
  let(:invoice) { create(:invoice, order: create(:completed_order_with_totals, store: store)) }
  let(:subscriber) { described_class.new }

  def event(record, name)
    double('Event', name: name, payload: { 'id' => record.prefixed_id }, matches?: false)
  end

  it 'emails a new invoice to the buyer' do
    expect { subscriber.call(event(invoice, 'invoice.created')) }.to have_enqueued_job(ActionMailer::MailDeliveryJob).
      with('Spree::InvoiceMailer', 'invoice_email', 'deliver_now', args: [invoice.id, { resend: false }])
  end

  it "stays silent when the store's own system sends invoices" do
    store.update!(preferred_send_invoice_email: false)

    expect { subscriber.call(event(invoice, 'invoice.created')) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it 'stays silent when customer emails are off' do
    store.update!(preferred_send_consumer_transactional_emails: false)

    expect { subscriber.call(event(invoice, 'invoice.created')) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it 'sends again on request, whatever the automatic setting says' do
    store.update!(preferred_send_invoice_email: false)

    expect { subscriber.call(event(invoice, 'invoice.delivery_requested')) }.to have_enqueued_job(ActionMailer::MailDeliveryJob).
      with('Spree::InvoiceMailer', 'invoice_email', 'deliver_now', args: [invoice.id, { resend: true }])
  end

  it "sends sellers their commission invoices even when the store's own system sends buyer invoices" do
    store.update!(preferred_send_invoice_email: false)
    seller = create(:seller, store: store, billing_email: 'accounts@seller.test')
    commission = create(:invoice, :commission, seller_payout: create(:seller_payout, seller: seller, store: store))

    expect { subscriber.call(event(commission, 'invoice.created')) }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it 'sends a commission invoice to the seller' do
    seller = create(:seller, store: store, billing_email: 'accounts@seller.test')
    commission = create(:invoice, :commission, seller_payout: create(:seller_payout, seller: seller, store: store))

    expect { subscriber.call(event(commission, 'invoice.created')) }.to have_enqueued_job(ActionMailer::MailDeliveryJob).
      with('Spree::InvoiceMailer', 'commission_invoice_email', 'deliver_now', args: [commission.id, { resend: false }])
  end
end
