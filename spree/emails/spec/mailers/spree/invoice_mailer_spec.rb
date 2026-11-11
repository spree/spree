require 'spec_helper'
require 'email_spec'

describe Spree::InvoiceMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:invoice) { create(:invoice, order: order, number: 'FV/2026/11/42') }

  describe '#invoice_email' do
    subject(:message) { described_class.invoice_email(invoice) }

    it "goes to the order's buyer, naming the document" do
      expect(message.to).to eq([order.email])
      expect(message.subject).to include('Invoice FV/2026/11/42')
    end

    it 'attaches the PDF' do
      expect(message.attachments.map(&:filename)).to eq([invoice.file.filename.to_s])
      expect(message.attachments.first.body.decoded).to start_with('%PDF')
    end

    it 'records that the invoice was sent once delivered' do
      expect { message.deliver_now }.to change { invoice.reload.sent_at }.from(nil)
    end

    it 'names a receipt as a receipt' do
      receipt = create(:invoice, :receipt, order: order, number: 'R-7')

      expect(described_class.invoice_email(receipt).subject).to include('Receipt R-7')
    end
  end

  describe '#commission_invoice_email' do
    let(:seller) { create(:seller, store: store, billing_email: 'accounts@seller.test') }
    let(:invoice) { create(:invoice, :commission, seller_payout: create(:seller_payout, seller: seller, store: store), number: 'COM-1') }

    subject(:message) { described_class.commission_invoice_email(invoice) }

    it "goes to the seller's billing address with the PDF" do
      expect(message.to).to eq(['accounts@seller.test'])
      expect(message.subject).to include('COM-1')
      expect(message.attachments.size).to eq(1)
    end
  end
end
