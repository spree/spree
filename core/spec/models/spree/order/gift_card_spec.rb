require 'spec_helper'

describe 'Order' do
  let(:order) { create(:order_with_line_items) }

  describe '#gift_card_total' do
    context 'when there is a gift card' do
      let(:gift_card) { create(:gift_card, amount: order.total) }

      before do
        order.apply_gift_card(gift_card)
      end

      it 'returns the gift card total' do
        expect(order.gift_card_total).to eq(gift_card.amount)
      end
    end
  end

  describe '#apply_gift_card' do
    context 'when there is a gift card' do
      let(:gift_card) { create(:gift_card, amount: order.total) }

      it 'applies the gift card to the order' do
        expect { order.apply_gift_card(gift_card) }.to change(order, :gift_card).from(nil).to(gift_card)
      end
    end
  end

  describe '#remove_gift_card' do
    context 'when there is a gift card' do
      let(:order) { create(:order_with_line_items, gift_card: gift_card) }
      let(:gift_card) { create(:gift_card) }

      it 'removes the gift card from the order' do
        expect { order.remove_gift_card }.to change(order, :gift_card).from(gift_card).to(nil)
      end
    end
  end
end
