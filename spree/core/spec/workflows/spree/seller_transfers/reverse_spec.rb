require 'spec_helper'

RSpec.describe Spree::SellerTransfers::Reverse do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:order) { create(:order, store: store, seller: seller, total: 100) }

  def earn(amount = 80)
    create(:seller_transfer, :completed, seller: seller, order: order, amount: amount)
  end

  describe 'taking money back' do
    it 'writes a negative row rather than editing the earning' do
      earning = earn

      result = described_class.call(order: order, amount: 30)

      expect(result).to be_success
      expect(result.value.amount).to eq(-30)
      expect(earning.reload.amount).to eq(80)
    end

    it 'leaves the seller with what is left' do
      earn
      described_class.call(order: order, amount: 30)

      expect(seller.balance('USD')).to eq(50)
    end

    it 'links the reversal to what it reverses' do
      earning = earn

      expect(described_class.call(order: order, amount: 30).value.reversed_from).to eq(earning)
    end
  end

  describe 'what it will not take back' do
    it 'refuses to claw back more than was credited' do
      earn(80)

      expect(described_class.call(order: order, amount: 200).value.amount).to eq(-80)
    end

    it 'takes nothing once the earning is fully reversed' do
      earn(80)
      described_class.call(order: order, amount: 80)

      expect { described_class.call(order: order, amount: 20) }.
        not_to change { Spree::SellerTransfer.count }
    end

    # An order refunded before it shipped never credited anybody.
    it 'does nothing when there was no earning' do
      expect { described_class.call(order: order, amount: 30) }.
        not_to change { Spree::SellerTransfer.count }
    end
  end

  # A settlement that has happened is never rewritten: the reversal is simply
  # unsettled, so the next sweep nets it off what comes after.
  describe 'when the earning was already settled' do
    it 'leaves the closed payout alone and waits for the next one' do
      payout = create(:seller_payout, :completed, seller: seller, amount: 80)
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80, payout: payout)

      reversal = described_class.call(order: order, amount: 30).value

      expect(payout.reload.amount).to eq(80)
      expect(reversal.payout).to be_nil
    end
  end
end
