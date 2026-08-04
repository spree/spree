require 'spec_helper'

RSpec.shared_examples 'a gift cards host' do
  describe '#gift_card_total / #total_minus_gift_cards' do
    let(:gift_card) { create(:gift_card, amount: record.total) }

    before { record.apply_gift_card(gift_card) }

    it 'returns the applied gift card total' do
      expect(record.gift_card_total).to eq(gift_card.amount)
      expect(record.total_minus_gift_cards).to eq(record.total - gift_card.amount)
    end
  end

  describe '#apply_gift_card' do
    let(:gift_card) { create(:gift_card, amount: record.total) }

    it 'applies the gift card to the record' do
      expect { record.apply_gift_card(gift_card) }.to change(record, :gift_card).from(nil).to(gift_card)
    end
  end

  describe '#remove_gift_card' do
    let(:gift_card) { create(:gift_card) }

    it 'removes the gift card from the record' do
      record.update!(gift_card: gift_card)

      expect { record.remove_gift_card }.to change(record, :gift_card).from(gift_card).to(nil)
    end
  end

  describe '#redeem_gift_card' do
    it 'is a no-op without a gift card' do
      expect(record.redeem_gift_card).to be_nil
    end
  end
end

RSpec.describe Spree::Purchase::GiftCards do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    let(:record) { create(:cart_with_line_items, store: store, customer: create(:user)) }

    it_behaves_like 'a gift cards host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order_with_line_items, store: store) }

    it_behaves_like 'a gift cards host'
  end
end
