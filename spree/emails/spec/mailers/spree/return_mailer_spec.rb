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

  describe '#requested_email' do
    let(:return_record) { create(:return, order: order, store: store, memo: 'Too small') }

    subject(:message) { described_class.requested_email(return_record) }

    it 'acknowledges the request, with the items and the customer note' do
      body = email_body(message)

      expect(message.to).to eq([order.email])
      expect(message.subject).to include(return_record.number)
      expect(body).to include(return_record.return_line_items.first.variant.product.name)
      expect(body).to include('Too small')
    end

    # A guest opens the order from the email with its token; a customer from
    # their account.
    it 'links a guest to the order page with its token' do
      expect(email_body(message)).to include("/orders/#{order.prefixed_id}?token=#{order.token}")
    end

    it 'links a customer to their account' do
      order.update_columns(customer_id: create(:user).id)

      expect(email_body(described_class.requested_email(return_record.reload))).to include("/account/orders/#{order.prefixed_id}")
    end

    it 'sends nothing once the request was withdrawn' do
      return_record.update_columns(status: 'canceled')

      expect(message.message).to be_a(ActionMailer::Base::NullMail)
    end
  end

  describe '#approved_email' do
    let(:return_record) { create(:return, order: order, store: store, status: 'approved', approved_at: Time.current) }

    it 'says where to send the items' do
      body = email_body(described_class.approved_email(return_record))

      expect(body).to include(return_record.stock_location.name)
      expect(body).to include('within 14 days')
    end
  end
end
