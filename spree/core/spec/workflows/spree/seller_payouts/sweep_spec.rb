require 'spec_helper'

RSpec.describe Spree::SellerPayouts::Sweep do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def earn(amount, currency: 'USD', status: 'completed', payout: nil)
    create(:seller_transfer, seller: seller, currency: currency, amount: amount, status: status, payout: payout,
                             order: create(:order, store: store, seller: seller, currency: currency))
  end

  describe 'what it settles' do
    it 'batches every unsettled earning into one payout' do
      earn(40)
      earn(30)

      result = described_class.call(seller: seller, currency: 'USD')

      expect(result).to be_success
      expect(result.value.amount).to eq(70)
      expect(result.value.transfers.count).to eq(2)
    end

    it 'names the earnings it covered, so a deposit can be reconciled' do
      first = earn(40)
      second = earn(30)

      payout = described_class.call(seller: seller, currency: 'USD').value

      expect(payout.transfers).to contain_exactly(first, second)
    end

    it 'leaves earnings in another currency for their own settlement' do
      earn(40)
      earn(30, currency: 'EUR')

      payout = described_class.call(seller: seller, currency: 'USD').value

      expect(payout.amount).to eq(40)
      expect(Spree::SellerTransfer.unsettled.where(currency: 'EUR').count).to eq(1)
    end

    it 'ignores earnings a previous settlement already took' do
      earn(40, payout: create(:seller_payout, seller: seller))
      earn(30)

      expect(described_class.call(seller: seller, currency: 'USD').value.amount).to eq(30)
    end

    it 'ignores an earning that is not yet confirmed' do
      earn(40)
      earn(30, status: 'pending')

      expect(described_class.call(seller: seller, currency: 'USD').value.amount).to eq(40)
    end
  end

  describe 'when there is nothing worth sending' do
    it 'does nothing for a seller who has earned nothing' do
      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end

    # The balance carries rather than being sent: a payout costs a fee either
    # way, and one meaningful deposit beats five trivial ones.
    it 'holds a balance below the seller’s threshold' do
      seller.update!(minimum_payout_amount: 50)
      earn(20)

      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
      expect(Spree::SellerTransfer.unsettled.count).to eq(1)
    end

    it 'holds a balance that reversals have taken negative' do
      earn(40)
      earn(-60)

      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end
  end

  # The stamp is the claim: a sweep only ever looks at unstamped earnings, so
  # a re-run finds nothing left to take.
  describe 'sweeping twice' do
    it 'takes nothing the first sweep already claimed' do
      earn(40)
      described_class.call(seller: seller, currency: 'USD')

      expect { described_class.call(seller: seller.reload, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end
  end

  describe 'the balance' do
    it 'is unchanged until the settlement is confirmed' do
      earn(40)
      described_class.call(seller: seller, currency: 'USD')

      expect(seller.balance('USD')).to eq(40)
    end

    it 'falls once the settlement completes' do
      earn(40)
      payout = described_class.call(seller: seller, currency: 'USD').value
      Spree.seller_payout_complete_workflow.call(seller_payout: payout)

      expect(seller.balance('USD')).to eq(0)
    end
  end
end
