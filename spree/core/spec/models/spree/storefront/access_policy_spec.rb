require 'spec_helper'

RSpec.describe Spree::Storefront::AccessPolicy, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:policy) { described_class.new(user: user, store: store) }
  let(:guest_policy) { described_class.new(user: nil, store: store) }

  describe '#purchase_readable?' do
    context 'with an owned order' do
      let(:order) { build(:order, customer: user) }

      it 'allows the owner' do
        expect(policy.purchase_readable?(order)).to be true
      end

      it 'denies other users' do
        other_policy = described_class.new(user: create(:user), store: store)
        expect(other_policy.purchase_readable?(order)).to be false
      end
    end

    context 'with a guest-token order' do
      let(:order) { build(:order, customer: nil, token: 'secret') }

      it 'allows the token bearer' do
        expect(guest_policy.purchase_readable?(order, token: 'secret')).to be true
      end

      it 'denies a wrong token' do
        expect(guest_policy.purchase_readable?(order, token: 'wrong')).to be false
      end

      it 'denies a missing token' do
        expect(guest_policy.purchase_readable?(order)).to be false
      end
    end

    context 'with a tokenless purchase' do
      let(:order) { build(:order, customer: nil, token: nil) }

      it 'never matches, even on a nil token' do
        expect(guest_policy.purchase_readable?(order, token: nil)).to be false
      end
    end

    it 'covers carts the same way' do
      cart = build(:cart, customer: user)
      expect(policy.purchase_readable?(cart)).to be true
      expect(guest_policy.purchase_readable?(cart)).to be false
    end
  end

  describe '#purchase_writable?' do
    let(:order) { build(:order, customer: user) }

    it 'allows the owner while incomplete' do
      allow(order).to receive(:completed?).and_return(false)
      expect(policy.purchase_writable?(order)).to be true
    end

    it 'denies once completed' do
      allow(order).to receive(:completed?).and_return(true)
      expect(policy.purchase_writable?(order)).to be false
    end

    it 'allows the token bearer while incomplete' do
      guest_order = build(:order, customer: nil, token: 'secret')
      allow(guest_order).to receive(:completed?).and_return(false)
      expect(guest_policy.purchase_writable?(guest_order, token: 'secret')).to be true
    end
  end

  describe '#orders_scope' do
    let!(:own_order) { create(:completed_order_with_totals, customer: user, store: store) }
    let!(:other_order) { create(:completed_order_with_totals, store: store) }

    it 'returns only the customer''s orders for an authenticated user' do
      expect(policy.orders_scope(store.orders.complete)).to contain_exactly(own_order)
    end

    it 'returns the token''s order for a guest' do
      scope = guest_policy.orders_scope(store.orders.complete, token: other_order.token)
      expect(scope).to contain_exactly(other_order)
    end

    it 'returns nothing for a guest without a token' do
      expect(guest_policy.orders_scope(store.orders.complete)).to be_empty
    end
  end
end
