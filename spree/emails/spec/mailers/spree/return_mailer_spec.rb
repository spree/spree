require 'spec_helper'
require 'email_spec'

describe Spree::ReturnMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, email: 'test@example.com', user: nil) }
  let(:return_record) { create(:received_return, order: order, store: store) }

  subject(:message) { described_class.refunded_email(return_record) }

  context ':from not set explicitly' do
    it 'falls back to store mail from address' do
      expect(message.from).to eq([store.mail_from_address])
    end
  end

  context ':reply_to not set explicitly' do
    it 'uses store customer support email' do
      expect(message.reply_to).to eq([store.customer_support_email])
    end
  end

  it 'goes to the address on the order' do
    expect(message.to).to eq([order.email])
  end

  it 'names the returned items' do
    variant = return_record.return_line_items.first.variant
    expect(message.body.encoded).to include(variant.product.name)
  end

  it 'accepts an id as well as a record' do
    expect(described_class.refunded_email(return_record.id).to).to eq([order.email])
  end

  # Every order-facing document renders the buyer's reference when present —
  # and both parts of it, not just the HTML one.
  context 'when the order carries a purchase order number' do
    before { order.update!(po_number: 'PO-4471') }

    it 'renders it in both parts' do
      expect(message.html_part.body.to_s).to include('PO-4471')
      expect(message.text_part.body.to_s).to include('PO-4471')
    end
  end
end
