require 'spec_helper'

RSpec.describe Spree::Storefront::AccessPolicy, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:policy) { described_class.new(user: user, store: store) }
  let(:guest_policy) { described_class.new(user: nil, store: store) }

  describe '#readable? / #writable? for carts and orders' do
    context 'with an owned order' do
      let(:order) { build(:order, customer: user) }

      it 'allows the owner' do
        expect(policy.readable?(order)).to be true
      end

      it 'denies other users' do
        other_policy = described_class.new(user: create(:user), store: store)
        expect(other_policy.readable?(order)).to be false
      end
    end

    context 'with a guest-token order' do
      let(:order) { build(:order, customer: nil, token: 'secret') }

      it 'allows the token bearer' do
        expect(guest_policy.readable?(order, token: 'secret')).to be true
      end

      it 'denies a wrong token' do
        expect(guest_policy.readable?(order, token: 'wrong')).to be false
      end

      it 'denies a missing token' do
        expect(guest_policy.readable?(order)).to be false
      end
    end

    context 'with a tokenless purchase' do
      let(:order) { build(:order, customer: nil, token: nil) }

      it 'never matches, even on a nil token' do
        expect(guest_policy.readable?(order, token: nil)).to be false
      end
    end

    it 'covers carts the same way' do
      cart = build(:cart, customer: user)
      expect(policy.readable?(cart)).to be true
      expect(guest_policy.readable?(cart)).to be false
    end

    describe 'writes' do
      let(:order) { build(:order, customer: user) }

      it 'allows the owner while incomplete' do
        allow(order).to receive(:completed?).and_return(false)
        expect(policy.writable?(order)).to be true
      end

      it 'denies once completed' do
        allow(order).to receive(:completed?).and_return(true)
        expect(policy.writable?(order)).to be false
      end

      it 'allows the token bearer while incomplete' do
        guest_order = build(:order, customer: nil, token: 'secret')
        allow(guest_order).to receive(:completed?).and_return(false)
        expect(guest_policy.writable?(guest_order, token: 'secret')).to be true
      end
    end
  end

  describe '#readable? / #writable? ownership default' do
    let(:own_wishlist) { build(:wishlist, customer: user) }
    let(:other_wishlist) { build(:wishlist, customer: create(:user)) }

    it 'allows the owner, read and write' do
      expect(policy.readable?(own_wishlist)).to be true
      expect(policy.writable?(own_wishlist)).to be true
    end

    it 'denies other users' do
      expect(policy.readable?(other_wishlist)).to be false
      expect(policy.writable?(other_wishlist)).to be false
    end

    it 'denies guests everything' do
      expect(guest_policy.readable?(own_wishlist)).to be false
      expect(guest_policy.writable?(own_wishlist)).to be false
    end

    it 'denies unowned records to everyone' do
      unowned = build(:address, customer_id: nil)
      expect(policy.readable?(unowned)).to be false
      expect(guest_policy.readable?(unowned)).to be false
    end

    it 'keys ownership on customer_id, not the deprecated user_id alias' do
      # Guards against the alias disappearing in 6.1: a record whose
      # customer_id matches is owned even if #user_id is gone.
      owned = build(:wishlist, customer: user)
      expect(owned.customer_id).to eq(user.id)
      expect(policy.readable?(owned)).to be true
    end

    it 'fails closed for records with no customer_id column' do
      # WishedItem has no ownership column — it is authorized through its
      # parent wishlist, never directly. The bare policy denies it.
      item = build(:wished_item)
      expect(item).not_to respond_to(:customer_id)
      expect(policy.readable?(item)).to be false
    end
  end

  describe '#scope' do
    context 'for orders (token semantics)' do
      let!(:own_order) { create(:completed_order_with_totals, customer: user, store: store) }
      let!(:other_order) { create(:completed_order_with_totals, store: store) }

      it 'returns only the customer''s orders for an authenticated user' do
        expect(policy.scope(store.orders.complete)).to contain_exactly(own_order)
      end

      it 'returns the token''s order for a guest' do
        scope = guest_policy.scope(store.orders.complete, token: other_order.token)
        expect(scope).to contain_exactly(other_order)
      end

      it 'returns nothing for a guest without a token' do
        expect(guest_policy.scope(store.orders.complete)).to be_empty
      end
    end

    context 'for any other resource (ownership default)' do
      let!(:own_wishlist) { create(:wishlist, customer: user, store: store) }
      let!(:other_wishlist) { create(:wishlist, customer: create(:user), store: store) }

      it 'returns only the caller''s records' do
        expect(policy.scope(Spree::Wishlist.for_store(store))).to contain_exactly(own_wishlist)
      end

      it 'returns nothing for guests' do
        expect(guest_policy.scope(Spree::Wishlist.for_store(store))).to be_empty
      end
    end
  end
end
