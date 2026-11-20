require 'spec_helper'
require 'email_spec'

describe Spree::ReturnMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, email: 'test@example.com', customer: nil) }
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
    expect(email_body(message)).to include(variant.product.name)
  end

  it 'states how many units were returned, not how many were ordered' do
    line_item = order.line_items.first
    line_item.update_columns(quantity: 3)
    order.fulfillment_items.sole.update_columns(quantity: 3)

    return_line = return_record.return_line_items.sole
    expect(return_line.credited_quantity).to eq(1)

    text = described_class.refunded_email(return_record).text_part.body.to_s

    expect(text).to include('1 x')
    expect(text).not_to include('3 x')
    expect(line_item.reload.quantity).to eq(3)
  end

  it 'omits a returned line the warehouse counted as none' do
    order = create(:shipped_order, store: store, email: 'test@example.com', customer: nil, line_items_count: 2)
    return_record = create(:received_return, order: order, store: store, line_items_count: 2)
    kept, dropped = return_record.return_line_items.to_a
    kept.line_item.product.update!(name: 'Kept Item')
    dropped.line_item.product.update!(name: 'Dropped Item')
    dropped.update!(received_quantity: 0)

    text = described_class.refunded_email(return_record).text_part.body.to_s

    expect(text).to include('Kept Item')
    expect(text).not_to include('Dropped Item')
    expect(text).not_to include('0 x')
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
