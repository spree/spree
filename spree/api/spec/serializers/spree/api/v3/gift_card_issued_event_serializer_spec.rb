require 'spec_helper'

RSpec.describe Spree::Api::V3::GiftCardIssuedEventSerializer do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { create(:line_item, order: order, product: create(:gift_card_product, store: store)) }
  let(:gift_card) { create(:gift_card, line_item: line_item, store: store, amount: 50) }

  subject(:payload) { JSON.parse(described_class.new(gift_card, params: { store: store, currency: order.currency }).serialize) }

  it 'names the order and line and masks the code' do
    expect(payload['order_id']).to eq(order.prefixed_id)
    expect(payload['line_item_id']).to eq(line_item.prefixed_id)
    expect(payload['code']).to eq(gift_card.masked_code)
  end

  it 'carries the recipient the buyer named' do
    line_item.assign_gift_card_recipient(email: 'friend@example.com', name: 'Alex')

    expect(payload['recipient']).to include('email' => 'friend@example.com', 'name' => 'Alex')
  end

  it 'carries no recipient when the card goes to the buyer' do
    expect(payload['recipient']).to be_nil
  end
end
