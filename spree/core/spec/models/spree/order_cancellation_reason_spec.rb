require 'spec_helper'

RSpec.describe Spree::OrderCancellationReason, type: :model do
  let(:store) { @default_store }

  describe 'name uniqueness' do
    it 'is scoped to the store, so two stores can each have their own' do
      create(:order_cancellation_reason, store: store, name: 'Out of stock')
      other_store_reason = build(:order_cancellation_reason, store: create(:store), name: 'Out of stock')

      expect(other_store_reason).to be_valid
    end

    it 'refuses a duplicate name within one store, ignoring case' do
      create(:order_cancellation_reason, store: store, name: 'Out of stock')
      duplicate = build(:order_cancellation_reason, store: store, name: 'out of STOCK')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end
  end

  describe '#can_be_deleted?' do
    let(:reason) { create(:order_cancellation_reason, store: store) }

    it { expect(reason.can_be_deleted?).to be true }

    context 'when an order was canceled for this reason' do
      before { create(:order, store: store, cancel_reason: reason) }

      it { expect(reason.can_be_deleted?).to be false }

      it 'refuses the destroy rather than orphaning the order' do
        expect(reason.destroy).to be false
        expect(reason.errors[:base]).to be_present
      end
    end
  end
end
