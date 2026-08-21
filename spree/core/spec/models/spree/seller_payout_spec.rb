require 'spec_helper'

RSpec.describe Spree::SellerPayout, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  it_behaves_like 'metadata'

  describe 'the transfers it settles' do
    let(:payout) { create(:seller_payout, seller: seller, amount: 60) }

    before do
      2.times do
        create(:seller_transfer, :completed, seller: seller, amount: 30, payout: payout,
                                             order: create(:order, store: store, seller: seller))
      end
    end

    it 'names exactly what it paid for' do
      expect(payout.transfers.count).to eq(2)
      expect(payout.transfers_total).to eq(60)
    end

    # A deleted settlement must not erase what the seller earned — the
    # transfers go back to being unsettled and the next sweep picks them up.
    it 'releases its transfers rather than destroying them when it goes' do
      payout.destroy!

      expect(Spree::SellerTransfer.count).to eq(2)
      expect(Spree::SellerTransfer.unsettled.count).to eq(2)
    end
  end

  describe '.owed' do
    it 'is money promised but not yet gone' do
      pending_payout = create(:seller_payout, seller: seller)
      processing = create(:seller_payout, seller: seller, status: 'processing')
      create(:seller_payout, :completed, seller: seller)

      expect(described_class.owed).to contain_exactly(pending_payout, processing)
    end
  end
end
