require 'spec_helper'

RSpec.describe Spree::SellerTransfer, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:order) { create(:order, store: store, seller: seller) }

  it_behaves_like 'metadata'

  describe 'one earning per order' do
    it 'refuses a second earning for the same order' do
      create(:seller_transfer, seller: seller, order: order)

      expect { create(:seller_transfer, seller: seller, order: order) }.
        to raise_error(ActiveRecord::RecordNotUnique)
    end

    # A refund can happen more than once, so reversals are deliberately
    # outside the constraint.
    it 'allows several reversals against the same order' do
      earning = create(:seller_transfer, seller: seller, order: order)

      expect {
        2.times { create(:seller_transfer, :reversal, seller: seller, order: order, reversed_from: earning) }
      }.not_to raise_error
    end
  end

  describe '#reversible_amount' do
    let(:earning) { create(:seller_transfer, :completed, seller: seller, order: order, amount: 40) }

    it 'is the whole earning while nothing has been given back' do
      expect(earning.reversible_amount).to eq(40)
    end

    it 'is what is left after a partial reversal' do
      create(:seller_transfer, :reversal, seller: seller, order: order, reversed_from: earning, amount: -15)

      expect(earning.reload.reversible_amount).to eq(25)
    end

    # However many times an order is refunded, a marketplace can never claw
    # back more than it credited.
    it 'floors at zero rather than going negative' do
      create(:seller_transfer, :reversal, seller: seller, order: order, reversed_from: earning, amount: -40)
      create(:seller_transfer, :reversal, seller: seller, order: order, reversed_from: earning, amount: -10)

      expect(earning.reload.reversible_amount).to eq(0)
    end

    it 'is nothing for a row that is itself a reversal' do
      reversal = create(:seller_transfer, :reversal, seller: seller, order: order, reversed_from: earning)

      expect(reversal.reversible_amount).to eq(0)
    end
  end

  describe '.unsettled' do
    it 'is what a payout sweep will pick up' do
      awaiting = create(:seller_transfer, :completed, seller: seller, order: order)
      create(:seller_transfer, :completed, seller: seller, order: create(:order, store: store, seller: seller),
                                           payout: create(:seller_payout, seller: seller))
      create(:seller_transfer, seller: seller, order: create(:order, store: store, seller: seller))

      expect(described_class.unsettled).to contain_exactly(awaiting)
    end
  end
end
