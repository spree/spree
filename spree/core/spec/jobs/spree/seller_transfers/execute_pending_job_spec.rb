require 'spec_helper'

RSpec.describe Spree::SellerTransfers::ExecutePendingJob do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store, payouts_enabled_at: Time.current) }

  def pending_earning(amount = 40)
    create(:seller_transfer, seller: seller, amount: amount, status: 'pending',
                             order: create(:order, store: store, seller: seller))
  end

  it 'sends what the provider could not be asked about before' do
    transfer = pending_earning

    described_class.perform_now(seller.id)

    expect(transfer.reload).to be_completed
  end

  it 'counts toward the balance once sent, so the next sweep settles it' do
    pending_earning

    expect { described_class.perform_now(seller.id) }.to change { seller.balance('USD') }.from(0).to(40)
  end

  it 'leaves an earning a settlement has already claimed' do
    transfer = pending_earning
    transfer.update!(payout: create(:seller_payout, seller: seller))

    described_class.perform_now(seller.id)

    expect(transfer.reload).to be_pending
  end

  # One seller's stuck earning must not stop the rest.
  it 'carries on past an earning the provider refuses' do
    first = pending_earning(40)
    second = pending_earning(30)
    allow_any_instance_of(Spree::PayoutProvider::System).to receive(:transfer!).and_wrap_original do |original, transfer|
      raise StandardError, 'provider down' if transfer.id == first.id

      original.call(transfer)
    end

    described_class.perform_now(seller.id)

    expect(first.reload).to be_pending
    expect(second.reload).to be_completed
  end

  # A reversal parks in `processing` the same way an earning does, and its
  # amount is negative — sending one would pay the seller the money it exists
  # to take back.
  it 'never sends a reversal as a payment' do
    earning = create(:seller_transfer, :completed, seller: seller, amount: 40,
                                                   order: create(:order, store: store, seller: seller))
    reversal = create(:seller_transfer, seller: seller, amount: -15, kind: 'refund_reversal',
                                        status: 'processing', reversed_from: earning,
                                        order: create(:order, store: store, seller: seller))

    expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:transfer!).with(reversal)

    described_class.perform_now(seller.id)

    expect(reversal.reload).to be_processing
  end

  it 'does nothing for a seller the provider still will not accept' do
    allow(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true)
    seller.update!(payouts_enabled_at: nil)
    transfer = pending_earning

    described_class.perform_now(seller.id)

    expect(transfer.reload).to be_pending
  end

  # This job is the retry, so leaving an earning it could not account for in a
  # retryable state means the next run sends the same money again.
  context 'when the provider cannot say whether the money moved' do
    before do
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:transfer!).
        and_raise(Spree::Core::AmbiguousGatewayError, 'connection timed out')
    end

    it 'parks the earning where no later run will send it' do
      transfer = pending_earning

      described_class.perform_now(seller.id)

      expect(transfer.reload).to be_unresolved
    end

    it 'does not offer it again on the next run' do
      pending_earning
      described_class.perform_now(seller.id)

      expect(seller.seller_transfers.earnings.retryable).to be_empty
    end
  end

  # A refusal means the money did not move, so the earning is still owed.
  it 'leaves a refused earning for the next run' do
    allow_any_instance_of(Spree::PayoutProvider::System).to receive(:transfer!).
      and_raise(StandardError, 'gateway down')
    transfer = pending_earning

    described_class.perform_now(seller.id)

    expect(transfer.reload).to be_pending
  end
end
