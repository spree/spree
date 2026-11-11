require 'spec_helper'
require 'email_spec'

describe Spree::GiftCardMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { create(:line_item, order: order, product: create(:gift_card_product, store: store)) }
  let(:gift_card) { create(:gift_card, line_item: line_item, store: store, amount: 50, expires_at: Date.new(2027, 11, 3)) }

  subject(:message) { described_class.issued_email(gift_card) }

  context 'with a recipient' do
    before { line_item.assign_gift_card_recipient(email: 'friend@example.com', name: 'Alex', message: 'Happy birthday!') }

    it 'goes to them with the code, the amount and the message' do
      body = email_body(message)

      expect(message.to).to eq(['friend@example.com'])
      expect(body).to include(gift_card.display_code, '$50.00', 'Hi Alex', 'Happy birthday!')
    end
  end

  it 'goes to the buyer when they named no one' do
    expect(message.to).to eq([order.email])
  end

  it 'is not sent for a canceled card' do
    gift_card.update_column(:status, 'canceled')

    expect(message.to).to be_nil
  end

  it 'is not sent for a card staff issued' do
    staff_card = create(:gift_card, store: store)

    expect(described_class.issued_email(staff_card).to).to be_nil
  end
end
