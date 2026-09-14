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
  # What a seller has earned and what their account can send are different
  # figures: money credited on fulfilment is funded by the customer's payment
  # and only becomes payable once that settles. Asking for the whole balance
  # regardless is how every payout gets refused.
  describe 'when the provider can send less than is owed' do
    def available(amount)
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:available_payout).and_return(amount)
    end

    it 'settles the oldest earnings that fit' do
      old = earn(40)
      earn(30)
      available(50)

      payout = described_class.call(seller: seller, currency: 'USD').value

      expect(payout.amount).to eq(40)
      expect(payout.transfers).to contain_exactly(old)
    end

    it 'leaves the rest for the next period' do
      earn(40)
      recent = earn(30)
      available(50)
      described_class.call(seller: seller, currency: 'USD')

      expect(seller.seller_transfers.unsettled).to contain_exactly(recent)
    end

    # A reversal is money already taken back. Leaving one out of a batch would
    # settle earnings it cancels, paying the seller for a refunded sale.
    it 'always counts reversals, whatever is available' do
      earning = earn(40)
      reversal = create(:seller_transfer, :reversal, :completed, seller: seller, currency: 'USD', amount: -10,
                                                                 reversed_from: earning, order: earning.order)
      available(30)

      payout = described_class.call(seller: seller, currency: 'USD').value

      expect(payout.amount).to eq(30)
      expect(payout.transfers).to contain_exactly(earning, reversal)
    end

    # Nothing has settled yet. Better to wait than to write a payout row a
    # provider is certain to refuse.
    it 'settles nothing when no earning fits' do
      earn(40)
      available(0)

      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
    end

    it 'settles everything when the provider names no limit' do
      earn(40)
      earn(30)
      available(nil)

      expect(described_class.call(seller: seller, currency: 'USD').value.amount).to eq(70)
    end

    # A provider that cannot say costs a period, not a payout: settling a
    # smaller batch would under-pay, and asking for everything is the bug.
    it 'settles nothing when the provider cannot say' do
      earn(40)
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:available_payout).
        and_raise(Spree::Core::AmbiguousGatewayError, 'timed out')

      expect { described_class.call(seller: seller, currency: 'USD') }.
        not_to change { Spree::SellerPayout.count }
      expect(seller.seller_transfers.unsettled.sum(:amount)).to eq(40)
    end

    # Reported rather than halted, so an operator pressing Settle is not told
    # the seller is owed nothing while the provider is merely unreachable.
    it 'says so rather than reading as nothing to settle' do
      earn(40)
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:available_payout).
        and_raise(Spree::Core::AmbiguousGatewayError, 'timed out')

      result = described_class.call(seller: seller, currency: 'USD')

      expect(result).to be_failure
      expect(result.error.to_s).to include('timed out')
    end
  end

  # A cross-border account settles in its own currency, so what a payout can
  # move is the settled figure — the sale's currency is money that account can
  # never send.
  describe 'when the seller banks in another currency' do
    def earn_converted(amount, settled, currency: 'USD', settled_currency: 'GBP', **attrs)
      create(:seller_transfer, seller: seller, currency: currency, amount: amount, status: 'completed',
                               settled_amount: settled, settled_currency: settled_currency,
                               order: create(:order, store: store, seller: seller, currency: currency), **attrs)
    end

    it 'settles in the currency the account holds' do
      earn_converted(69.80, 51.60)

      payout = described_class.call(seller: seller, currency: 'GBP').value

      expect(payout.currency).to eq('GBP')
      expect(payout.amount).to eq(51.60)
    end

    it 'has nothing to settle in the currency the sale was priced in' do
      earn_converted(69.80, 51.60)

      expect(described_class.call(seller: seller, currency: 'USD').value).to eq(seller)
    end

    # Left in the sale's currency a clawback would never join the batch that
    # pays the earning it cancels, and the seller would keep both.
    it 'nets a clawback that settled alongside its earning' do
      earning = earn_converted(69.80, 51.60)
      earn_converted(-21.60, -15.97, kind: 'refund_reversal', reversed_from: earning)

      expect(described_class.call(seller: seller, currency: 'GBP').value.amount).to eq(35.63)
    end

    # The ceiling comes back from the provider in the account's own currency,
    # so the rows it is compared against have to be in that currency too.
    it 'compares what is available against the settled figures' do
      earn_converted(69.80, 51.60)
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:available_payout).and_return(40)

      expect { described_class.call(seller: seller, currency: 'GBP') }.
        not_to change { Spree::SellerPayout.count }
    end

    it 'leaves a seller who banks in the currency they sold in alone' do
      earn(40)

      expect(described_class.call(seller: seller, currency: 'USD').value.amount).to eq(40)
    end
  end

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
