require 'spec_helper'

RSpec.describe Spree::GiftCard, type: :model do
  let(:store) { @default_store }

  it_behaves_like 'lifecycle events'

  describe 'Callbacks' do
    describe '#ensure_can_be_deleted' do
      it "ensures a used gift card can't be destroyed" do
        expect(create(:gift_card, state: :redeemed).destroy).to be(false)
        expect(create(:gift_card, state: :partially_redeemed).destroy).to be(false)
        expect(create(:gift_card, state: :active).destroy).to be_destroyed
        expect(create(:gift_card, state: :canceled).destroy).to be_destroyed
      end

      it 'adds an error' do
        gift_card = create(:gift_card, state: :redeemed)
        gift_card.destroy

        expect(gift_card).to_not be_destroyed
        expect(gift_card.errors.messages).to eq(base: ["Can't delete a used gift card"])
      end
    end
  end

  describe 'Scopes' do
    let(:active_gift_card) { create(:gift_card, state: :active) }
    let(:redeemed_gift_card) { create(:gift_card, state: :redeemed) }
    let(:partially_redeemed_gift_card) { create(:gift_card, state: :partially_redeemed) }
    let(:expired_gift_card) { create(:gift_card, expires_at: Date.current, state: :active) }

    describe '#active' do
      it 'returns active gift cards' do
        expect(described_class.active).to contain_exactly(active_gift_card)
      end
    end

    describe '#expired' do
      it 'returns expired gift cards' do
        expect(described_class.expired).to contain_exactly(expired_gift_card)
      end
    end

    describe '#redeemed' do
      it 'returns redeemed gift cards' do
        expect(described_class.redeemed).to contain_exactly(redeemed_gift_card)
      end
    end

    describe '#partially_redeemed' do
      it 'returns partially redeemed gift cards' do
        expect(described_class.partially_redeemed).to contain_exactly(partially_redeemed_gift_card)
      end
    end
  end

  describe '#active?' do
    context 'when expired' do
      let(:gift_card) { build(:gift_card, expires_at: Date.current, state: :active) }

      it 'returns false' do
        expect(gift_card.active?).to be(false)
      end
    end

    context 'when redeemed' do
      let(:gift_card) { build(:gift_card, state: :redeemed) }

      it 'returns false' do
        expect(gift_card.active?).to be(false)
      end
    end

    context 'when active' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.from_now, state: :active) }

      it 'returns true' do
        expect(gift_card.active?).to be(true)
      end
    end
  end

  describe '#amount_remaining' do
    context 'when active' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 0, amount_authorized: 0, state: :active) }

      it 'returns the remaining amount' do
        expect(gift_card.amount_remaining).to eq(100)
      end
    end

    context 'when redeemed' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 100, amount_authorized: 0, state: :redeemed) }

      it 'returns 0' do
        expect(gift_card.amount_remaining).to eq(0)
      end
    end

    context 'when authorized' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 0, amount_authorized: 50, state: :partially_redeemed) }

      it 'returns the remaining amount' do
        expect(gift_card.amount_remaining).to eq(50)
      end
    end
  end

  describe '#display_state' do
    context 'when expired' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.ago, state: :active) }

      it 'returns expired' do
        expect(gift_card.display_state).to eq 'expired'
      end
    end

    context 'when active' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.from_now, state: :active) }

      it 'returns active' do
        expect(gift_card.display_state).to eq 'active'
      end
    end
  end

  describe '#to_csv' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
    let(:gift_card) { create(:gift_card, store: store, user: user, amount: 50.00) }

    subject { gift_card.to_csv }

    it 'returns an array' do
      expect(subject).to be_an(Array)
    end

    it 'returns the correct number of fields' do
      expect(subject.length).to eq(12)
    end

    it 'includes the gift card code' do
      expect(subject[0]).to eq(gift_card.display_code)
    end

    it 'includes the currency' do
      expect(subject[4]).to eq(gift_card.currency)
    end

    it 'includes the user email' do
      expect(subject[7]).to eq(user.email)
    end
  end

  describe 'State transitions' do
  let(:store) { Spree::Store.default }

  context 'when active' do
    let(:gift_card) { create(:gift_card, state: :active, amount: 100, amount_used: 0, store: store) }

    it 'transitions from active to partially_redeemed' do
      expect { gift_card.partial_redeem! }
        .to change(gift_card, :state).from('active').to('partially_redeemed')
    end

    it 'transitions from active to redeemed' do
      expect { gift_card.redeem! }
        .to change(gift_card, :state).from('active').to('redeemed')
    end
  end

  context 'when partially_redeemed' do
    let(:gift_card) { create(:gift_card, state: :partially_redeemed, amount: 100, amount_used: 50, store: store) }

    it 'allows multiple partial redemptions (remains partially_redeemed)' do
      expect { gift_card.partial_redeem! }
        .to_not change(gift_card, :state)
      expect(gift_card.state).to eq('partially_redeemed')
    end

    it 'transitions from partially_redeemed to redeemed when fully used' do
      gift_card.update!(amount_used: 100)
      expect { gift_card.redeem! }
        .to change(gift_card, :state).from('partially_redeemed').to('redeemed')
    end
  end

  context 'when redeemed' do
    let(:gift_card) { create(:gift_card, state: :redeemed, amount: 100, amount_used: 100, store: store) }

    it 'does not allow further redemption' do
      expect { gift_card.partial_redeem! }.to raise_error(StateMachines::InvalidTransition)
      expect { gift_card.redeem! }.to raise_error(StateMachines::InvalidTransition)
    end
  end
  end

  describe 'custom events', events: true do
    let(:store) { Spree::Store.default }

    describe 'gift_card.redeemed' do
      let(:gift_card) { create(:gift_card, state: :active, amount: 100, amount_used: 0, store: store) }

      it 'publishes gift_card.redeemed event when fully redeemed' do
        expect(gift_card).to receive(:publish_event).with('gift_card.redeemed')
        allow(gift_card).to receive(:publish_event).with(anything)

        gift_card.redeem!
      end
    end

    describe 'gift_card.partially_redeemed' do
      let(:gift_card) { create(:gift_card, state: :active, amount: 100, amount_used: 0, store: store) }

      it 'publishes gift_card.partially_redeemed event when partially redeemed' do
        expect(gift_card).to receive(:publish_event).with('gift_card.partially_redeemed')
        allow(gift_card).to receive(:publish_event).with(anything)

        gift_card.partial_redeem!
      end
    end
  end
end
