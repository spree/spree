require 'spec_helper'

RSpec.describe Spree::GiftCards::Redeem do
  subject { described_class.call(gift_card: gift_card) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store) }
  let(:gift_card) { create(:gift_card, amount: 50, store: store) }

  before do
    order.update_column(:total, 30)
    order.update_column(:shipment_total, 10)
  end

  context 'when the gift card has no amount remaining' do
    before { gift_card.update!(amount_used: gift_card.amount) }

    it 'calls redeem! on the gift card' do
      expect(gift_card).to receive(:redeem!)
      subject
    end

    it 'returns success with the gift card' do
      expect(subject).to be_success
      expect(subject.value).to eq(gift_card)
    end
  end

  context 'when the gift card has amount remaining' do
    before { gift_card.update!(amount_used: 20) }

    it 'calls partial_redeem! on the gift card' do
      expect(gift_card).to receive(:partial_redeem!)
      subject
    end

    it 'returns success with the gift card' do
      expect(subject).to be_success
      expect(subject.value).to eq(gift_card)
    end
  end
end
