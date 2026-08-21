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

  # A subscriber job retries on error, so the same refund can be handled more
  # than once. Without a key tying a reversal to its cause, each attempt would
  # take the money back again.
  describe 'when the same refund arrives twice' do
    let(:refund) { create(:refund, amount: 30) }

    it 'takes the money back once' do
      earn(80)
      described_class.call(order: order, amount: 30, refund: refund)

      expect { described_class.call(order: order, amount: 30, refund: refund) }.
        not_to change { Spree::SellerTransfer.count }

      expect(seller.balance('USD')).to eq(50)
    end

    it 'answers with the reversal that was already written' do
      earn(80)
      first = described_class.call(order: order, amount: 30, refund: refund).value

      expect(described_class.call(order: order, amount: 30, refund: refund).value).to eq(first)
    end

    # The read guard is not enough on its own — two deliveries can pass it
    # together — so the database has the last word.
    it 'refuses a second row even when the read guard is bypassed' do
      earning = earn(80)

      expect do
        Spree::SellerTransfer.create!(
          store: store, seller: seller, order: order, reversed_from: earning, refund: refund,
          amount: -30, currency: 'USD', kind: 'refund_reversal', provider: 'system', status: 'pending'
        )
        Spree::SellerTransfer.create!(
          store: store, seller: seller, order: order, reversed_from: earning, refund: refund,
          amount: -30, currency: 'USD', kind: 'refund_reversal', provider: 'system', status: 'pending'
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'when two different refunds land on one order' do
    it 'never takes back more than was credited between them' do
      earn(80)

      described_class.call(order: order, amount: 60, refund: create(:refund, amount: 30))
      described_class.call(order: order, amount: 60, refund: create(:refund, amount: 30))

      expect(seller.balance('USD')).to eq(0)
      expect(Spree::SellerTransfer.reversals_only.sum(:amount)).to eq(-80)
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
