require 'spec_helper'

RSpec.describe Spree::GiftCards::Cancel do
  subject { described_class.call(gift_card: gift_card) }

  let(:store) { Spree::Store.default }
  let(:gift_card) { create(:gift_card, amount: 50, store: store) }

  it 'cancels an unspent card' do
    expect { subject }.to change { gift_card.reload.status }.from('active').to('canceled')
    expect(subject).to be_success
  end

  it 'publishes gift_card.canceled', events: true do
    allow(gift_card).to receive(:publish_event).with(anything)
    expect(gift_card).to receive(:publish_event).with('gift_card.canceled')
    subject
  end

  context 'when the card has already been spent against' do
    before { gift_card.update!(status: 'partially_redeemed', amount_used: 20) }

    it 'refuses, so spent value is not taken back' do
      expect(subject).not_to be_success
      expect(gift_card.reload.status).to eq('partially_redeemed')
    end
  end

  context 'when already canceled' do
    before { gift_card.update!(status: 'canceled') }

    it 'fails' do
      expect(subject).not_to be_success
    end
  end
end
