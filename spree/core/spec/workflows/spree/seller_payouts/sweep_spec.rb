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

    # A pending earning is one the provider has not confirmed. Clearing those
    # is `SellerTransfers::ExecutePendingJob`'s job, driven by the seller
    # becoming payable rather than by the calendar.
    it 'leaves an earning the provider has not confirmed' do
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

  # A payout is created by the sweep and by nothing else, so earnings left
  # stamped to a failed one would be unreachable — skipped by every later
  # sweep while the balance still says the seller is owed them.
  describe 'when the provider will not pay' do
    before do
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:pay!).and_raise(StandardError, 'gateway down')
    end

    it 'reports the failure' do
      earn(40)

      expect(described_class.call(seller: seller, currency: 'USD')).to be_failure
    end

    it 'releases the earnings so the next sweep is the retry' do
      earn(40)
      described_class.call(seller: seller, currency: 'USD')

      expect(seller.seller_transfers.unsettled.sum(:amount)).to eq(40)
    end

    it 'still owes the seller their money' do
      earn(40)
      described_class.call(seller: seller, currency: 'USD')

      expect(seller.balance('USD')).to eq(40)
    end

    it 'settles them on the next run' do
      earn(40)
      described_class.call(seller: seller, currency: 'USD')
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:pay!).and_call_original

      expect(described_class.call(seller: seller.reload, currency: 'USD').value.amount).to eq(40)
    end
  end

  # A timeout is not a refusal: the provider may have moved the money before
  # the answer was lost. Releasing the earnings here is what would let a later
  # sweep pay them a second time, since an idempotency key only holds for as
  # long as the provider keeps its record.
  describe 'when nobody knows whether the money moved' do
    before do
      earn(40)
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:pay!).
        and_raise(Spree::Core::AmbiguousGatewayError, 'connection timed out')
    end

    it 'reports the failure' do
      expect(described_class.call(seller: seller, currency: 'USD')).to be_failure
    end

    it 'holds the earnings rather than letting them fall into another payout' do
      described_class.call(seller: seller, currency: 'USD')

      expect(seller.seller_transfers.unsettled).to be_empty
    end

    it 'sends nothing on the next sweep' do
      described_class.call(seller: seller, currency: 'USD')
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:pay!).and_call_original

      expect { described_class.call(seller: seller.reload, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end

    it 'leaves the settlement waiting to be resolved' do
      described_class.call(seller: seller, currency: 'USD')

      expect(Spree::SellerPayout.last).to be_unresolved
    end

    # It is not owed — it may already have been sent — and it is not settled
    # either, so it belongs in neither queue until somebody says which.
    it 'stops counting it as money still to send' do
      described_class.call(seller: seller, currency: 'USD')

      expect(Spree::SellerPayout.owed).to be_empty
    end
  end

  # A concurrent sweep can claim rows this one counted, leaving it holding
  # nothing. Asking a provider to move zero is not a settlement.
  describe 'when another sweep claimed everything first' do
    let(:workflow) { described_class.new }

    before do
      earn(40)
      # The other sweep wins the race: it takes the rows between this one
      # counting them and claiming them.
      allow(Spree::SellerTransfer).to receive(:where).and_return(Spree::SellerTransfer.none)
    end

    it 'sends nothing' do
      expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:pay!)

      described_class.call(seller: seller, currency: 'USD')
    end

    it 'keeps no empty settlement behind' do
      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end
  end
end
