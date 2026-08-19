require 'spec_helper'

RSpec.describe Spree::GiftCard, type: :model do
  let(:store) { @default_store }

  it_behaves_like 'lifecycle events'

  describe 'Callbacks' do
    describe '#generate_code' do
      it 'generates a code when blank' do
        gift_card = build(:gift_card, code: nil)
        gift_card.valid?
        expect(gift_card.code).to be_present
      end

      it 'generates a code when blank string is given' do
        gift_card = build(:gift_card, code: '')
        gift_card.valid?
        expect(gift_card.code).to be_present
      end

      it 'preserves the provided code when present' do
        gift_card = build(:gift_card, code: 'mycode123')
        gift_card.valid?
        expect(gift_card.code).to eq('mycode123')
      end
    end

    describe '#ensure_can_be_deleted' do
      it "ensures a used gift card can't be destroyed" do
        expect(create(:gift_card, status: :redeemed).destroy).to be(false)
        expect(create(:gift_card, status: :partially_redeemed).destroy).to be(false)
        expect(create(:gift_card, status: :active).destroy).to be_destroyed
        expect(create(:gift_card, status: :canceled).destroy).to be_destroyed
      end

      it 'adds an error' do
        gift_card = create(:gift_card, status: :redeemed)
        gift_card.destroy

        expect(gift_card).to_not be_destroyed
        expect(gift_card.errors.messages).to eq(base: ["Can't delete a used gift card"])
      end
    end
  end

  describe 'Scopes' do
    let(:active_gift_card) { create(:gift_card, status: :active) }
    let(:redeemed_gift_card) { create(:gift_card, status: :redeemed) }
    let(:partially_redeemed_gift_card) { create(:gift_card, status: :partially_redeemed) }
    let(:expired_gift_card) { create(:gift_card, expires_at: Date.current, status: :active) }

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
      let(:gift_card) { build(:gift_card, expires_at: Date.current, status: :active) }

      it 'returns false' do
        expect(gift_card.active?).to be(false)
      end
    end

    context 'when redeemed' do
      let(:gift_card) { build(:gift_card, status: :redeemed) }

      it 'returns false' do
        expect(gift_card.active?).to be(false)
      end
    end

    context 'when active' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.from_now, status: :active) }

      it 'returns true' do
        expect(gift_card.active?).to be(true)
      end
    end
  end

  describe '#amount_remaining' do
    context 'when active' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 0, amount_authorized: 0, status: :active) }

      it 'returns the remaining amount' do
        expect(gift_card.amount_remaining).to eq(100)
      end
    end

    context 'when redeemed' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 100, amount_authorized: 0, status: :redeemed) }

      it 'returns 0' do
        expect(gift_card.amount_remaining).to eq(0)
      end
    end

    context 'when authorized' do
      let(:gift_card) { build(:gift_card, amount: 100, amount_used: 0, amount_authorized: 50, status: :partially_redeemed) }

      it 'returns the remaining amount' do
        expect(gift_card.amount_remaining).to eq(50)
      end
    end
  end

  describe '#display_status' do
    context 'when expired' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.ago, status: :active) }

      it 'returns expired' do
        expect(gift_card.display_status).to eq 'expired'
      end
    end

    context 'when active' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.from_now, status: :active) }

      it 'returns active' do
        expect(gift_card.display_status).to eq 'active'
      end
    end
  end

  describe '#to_csv' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
    let(:gift_card) { create(:gift_card, store: store, customer: user, amount: 50.00) }

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

  describe 'status' do
    it 'has no state machine' do
      expect(described_class).not_to respond_to(:state_machines)
    end

    it 'defaults to active' do
      expect(described_class.new.status).to eq('active')
    end

    it 'rejects an unknown status' do
      expect(build(:gift_card, status: 'nonsense')).not_to be_valid
    end
  end

  describe 'status scopes and predicates' do
    let(:store) { Spree::Store.default }
    let!(:active) { create(:gift_card, store: store, amount: 10) }
    let!(:partial) { create(:gift_card, store: store, amount: 10, status: 'partially_redeemed') }
    let!(:redeemed) { create(:gift_card, store: store, amount: 10, status: 'redeemed') }
    let!(:expired) { create(:gift_card, store: store, amount: 10, expires_at: 1.day.ago) }

    it 'treats a partially redeemed card as still spendable and an expired one as not' do
      expect(described_class.active).to include(active, partial)
      expect(described_class.active).not_to include(redeemed, expired)
    end

    it 'reports an expired card as inactive even though its status is active' do
      expect(expired.status).to eq('active')
      expect(expired).not_to be_active
      expect(expired).to be_expired
    end

    it 'exposes the plain column lookup through with_status' do
      expect(described_class.with_status(:active)).to include(active, expired)
      expect(described_class.with_status(:active, :redeemed)).to include(active, redeemed)
    end
  end

  describe 'deprecated state bridge' do
    let(:gift_card) { build(:gift_card, status: :redeemed) }

    it 'reads status' do
      expect(Spree::Deprecation).to receive(:warn)
      expect(gift_card.state).to eq('redeemed')
    end

    it 'writes status' do
      expect(Spree::Deprecation).to receive(:warn)
      gift_card.state = 'active'
      expect(gift_card.status).to eq('active')
    end
  end
end
