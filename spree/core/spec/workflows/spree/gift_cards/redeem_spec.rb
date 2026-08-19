require 'spec_helper'

RSpec.describe Spree::GiftCards::Redeem do
  subject { described_class.call(gift_card: gift_card) }

  let(:store) { Spree::Store.default }
  let(:gift_card) { create(:gift_card, amount: 50, store: store) }

  context 'when the gift card has no amount remaining' do
    before { gift_card.update!(amount_used: gift_card.amount) }

    it 'marks it redeemed and stamps redeemed_at' do
      expect { subject }.to change { gift_card.reload.status }.from('active').to('redeemed')
      expect(gift_card.redeemed_at).to be_present
    end

    it 'returns success with the gift card' do
      expect(subject).to be_success
      expect(subject.value).to eq(gift_card)
    end

    it 'publishes gift_card.redeemed', events: true do
      allow(gift_card).to receive(:publish_event).with(anything)
      expect(gift_card).to receive(:publish_event).with('gift_card.redeemed')
      subject
    end
  end

  context 'when the gift card has amount remaining' do
    before { gift_card.update!(amount_used: 20) }

    it 'marks it partially redeemed without stamping redeemed_at' do
      expect { subject }.to change { gift_card.reload.status }.from('active').to('partially_redeemed')
      expect(gift_card.redeemed_at).to be_nil
    end

    it 'publishes gift_card.partially_redeemed', events: true do
      allow(gift_card).to receive(:publish_event).with(anything)
      expect(gift_card).to receive(:publish_event).with('gift_card.partially_redeemed')
      subject
    end

    it 'republishes on a further partial redemption' do
      described_class.call(gift_card: gift_card)

      allow(gift_card).to receive(:publish_event).with(anything)
      expect(gift_card).to receive(:publish_event).with('gift_card.partially_redeemed')
      described_class.call(gift_card: gift_card)
    end
  end

  context 'when the gift card is already redeemed' do
    before { gift_card.update!(status: 'redeemed', amount_used: gift_card.amount) }

    it 'fails rather than redeeming twice' do
      expect(subject).not_to be_success
    end
  end
end
