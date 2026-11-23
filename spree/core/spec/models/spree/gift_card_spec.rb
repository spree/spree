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

      # Applying a card draws it down and pays with a store credit made from
      # it while the card stays active; deleting it would leave that payment
      # funding the order with no card behind it.
      context 'when an open cart holds the card' do
        let(:gift_card) { create(:gift_card, store: store, amount: 60) }
        let(:cart) { create(:cart_with_line_items, store: store, line_items_price: 60) }

        before do
          cart.update_column(:total, 60)
          expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: cart)).to be_success
          gift_card.reload
        end

        it 'refuses the delete and keeps the card' do
          expect(gift_card.status).to eq('active')
          expect(gift_card.can_be_deleted?).to be(false)
          expect(gift_card.destroy).to be(false)
          expect(Spree::GiftCard.exists?(gift_card.id)).to be(true)
        end

        it 'allows the delete once the card is taken off the cart' do
          expect(Spree.gift_card_remove_workflow.call(order: cart.reload)).to be_success

          expect(gift_card.reload.can_be_deleted?).to be(true)
          expect(gift_card.destroy).to be_destroyed
        end
      end

      context 'when a draft order holds the card without drawing on it' do
        let(:gift_card) { create(:gift_card, store: store) }

        it 'refuses the delete' do
          create(:order, store: store, gift_card: gift_card)

          expect(gift_card.reload.destroy).to be(false)
        end
      end

      it 'allows deleting a card only completed orders used' do
        gift_card = create(:gift_card, store: store, status: :active)
        create(:completed_order_with_totals, store: store, gift_card: gift_card)

        expect(gift_card.reload.destroy).to be_destroyed
      end
    end
  end

  describe 'Validations' do
    describe 'amount and currency once the card has been used' do
      let(:gift_card) { create(:gift_card, store: store, amount: 100, currency: 'USD') }

      before { gift_card.update_columns(amount_used: 44, status: 'partially_redeemed') }

      it 'refuses to raise the amount' do
        gift_card.amount = 150

        expect(gift_card).not_to be_valid
        expect(gift_card.errors.details[:amount]).to include(error: :cannot_change_once_used)
      end

      it 'refuses to lower the amount' do
        gift_card.amount = 40

        expect(gift_card).not_to be_valid
        expect(gift_card.errors.details[:amount]).to include(error: :cannot_change_once_used)
      end

      it 'refuses to change the currency' do
        gift_card.currency = 'EUR'

        expect(gift_card).not_to be_valid
        expect(gift_card.errors.details[:currency]).to include(error: :cannot_change_once_used)
      end

      it 'accepts the same amount written differently' do
        gift_card.amount = '100.00'

        expect(gift_card).to be_valid
      end

      it 'still lets other attributes change' do
        gift_card.expires_at = 1.year.from_now.to_date
        gift_card.amount_used = 60

        expect(gift_card).to be_valid
      end

      it 'refuses to change the amount while part of the card is authorized' do
        gift_card.update_columns(amount_used: 0, amount_authorized: 20, status: 'active')
        gift_card.amount = 150

        expect(gift_card).not_to be_valid
        expect(gift_card.errors.details[:amount]).to include(error: :cannot_change_once_used)
      end

      it 'lets an unused card change its amount and currency' do
        gift_card.update_columns(amount_used: 0, status: 'active')
        gift_card.amount = 150
        gift_card.currency = 'EUR'

        expect(gift_card).to be_valid
      end
    end
  end

  describe 'Scopes' do
    let!(:active_gift_card) { create(:gift_card, status: :active) }
    let!(:redeemed_gift_card) { create(:gift_card, status: :redeemed) }
    let!(:partially_redeemed_gift_card) { create(:gift_card, status: :partially_redeemed) }
    let!(:expired_gift_card) { create(:gift_card, expires_at: Date.current, status: :active) }

    describe '#masked_code' do
      it 'shows only the last four characters' do
        expect(build(:gift_card, code: 'abcd1234wxyz').masked_code).to eq('********WXYZ')
      end
    end

    describe '#active' do
      it 'returns unexpired active and partially redeemed gift cards' do
        expect(described_class.active).to contain_exactly(active_gift_card, partially_redeemed_gift_card)
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

  describe '#open_holds' do
    let(:store) { Spree::Store.default }
    let(:gift_card) { create(:gift_card, store: store) }

    let!(:open_cart) { create(:cart, store: store, gift_card: gift_card) }
    let!(:open_order) { create(:order, store: store, gift_card: gift_card) }
    let!(:completed_order) { create(:order, store: store, gift_card: gift_card, completed_at: Time.current) }
    let!(:canceled_order) { create(:order, store: store, gift_card: gift_card, status: 'canceled') }
    let!(:unrelated_cart) { create(:cart, store: store) }

    it 'returns only the carts and orders still holding the balance' do
      expect(gift_card.open_holds).to contain_exactly(open_cart, open_order)
    end

    it 'excludes the record being applied to' do
      expect(gift_card.open_holds(except: open_cart)).to contain_exactly(open_order)
    end

    it 'excludes on type as well as id' do
      # An Order stand-in carrying the cart's id must not exclude the cart,
      # and must still exclude the order it really names.
      stand_in = Spree::Order.new(id: open_cart.id)

      expect(gift_card.open_holds(except: stand_in)).to include(open_cart)
      expect(gift_card.open_holds(except: Spree::Order.new(id: open_order.id))).not_to include(open_order)
    end

    context 'when a cart is mid-completion' do
      before { open_cart.update_column(:completing_at, Time.current) }

      it 'is not releasable' do
        expect(gift_card.open_holds).to contain_exactly(open_order)
      end

      it 'is reported as being completed' do
        expect(gift_card.holds_being_completed).to contain_exactly(open_cart)
      end

      it 'is not reported once the claim goes stale' do
        open_cart.update_column(:completing_at, 1.day.ago)

        expect(gift_card.holds_being_completed).to be_empty
        expect(gift_card.open_holds).to include(open_cart)
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
