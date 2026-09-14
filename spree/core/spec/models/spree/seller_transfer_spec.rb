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

  # A sale is priced in the customer's currency; the seller's account settles in
  # its own. Both figures are recorded, and the settlement one is what a payout
  # can actually move.
  describe 'settlement' do
    let(:seller) { create(:seller, :approved, store: store) }

    def transfer(**attrs)
      create(:seller_transfer, seller: seller, currency: 'USD', amount: 69.80,
                               order: create(:order, store: store, seller: seller), **attrs)
    end

    it 'answers what the account received when the provider converted' do
      row = transfer(settled_amount: 51.60, settled_currency: 'GBP')

      expect(row.settlement_amount).to eq(51.60)
      expect(row.settlement_currency).to eq('GBP')
      expect(row).to be_converted
    end

    it 'falls back to the sale when no settlement was reported' do
      row = transfer

      expect(row.settlement_amount).to eq(69.80)
      expect(row.settlement_currency).to eq('USD')
      expect(row).not_to be_converted
    end

    it 'is not a conversion when the provider settled in the same currency' do
      expect(transfer(settled_amount: 69.80, settled_currency: 'USD')).not_to be_converted
    end

    # An aggregate over an expression carries no column type, so the adapter
    # decides what comes back — a Float on SQLite and MySQL. Money is not kept
    # in one.
    it 'sums settlement in decimal, whatever the adapter' do
      transfer(settled_amount: 51.60, settled_currency: 'GBP')

      expect(Spree::SellerTransfer.settling_in('GBP').settlement_total).to be_a(BigDecimal)
      expect(seller.balance('GBP')).to be_a(BigDecimal)
    end

    it 'sums the sale figure for rows no provider has settled' do
      transfer
      transfer(settled_amount: 51.60, settled_currency: 'GBP')

      expect(Spree::SellerTransfer.settling_in('USD').settlement_total).to eq(69.80)
      expect(Spree::SellerTransfer.settling_in('GBP').settlement_total).to eq(51.60)
    end

    it 'groups by the currency a payout could send' do
      converted = transfer(settled_amount: 51.60, settled_currency: 'GBP')
      plain = transfer

      expect(Spree::SellerTransfer.settling_in('GBP')).to contain_exactly(converted)
      expect(Spree::SellerTransfer.settling_in('USD')).to contain_exactly(plain)
      expect(Spree::SellerTransfer.where(seller: seller).settlement_currencies).to match_array(%w[GBP USD])
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
