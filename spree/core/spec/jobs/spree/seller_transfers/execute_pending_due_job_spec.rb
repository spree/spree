require 'spec_helper'

RSpec.describe Spree::SellerTransfers::ExecutePendingDueJob do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def enqueued_seller_ids
    enqueued_jobs.
      select { |job| job[:job] == Spree::SellerTransfers::ExecutePendingJob }.
      map { |job| job[:args].first }
  end

  def earning(status:, owner: nil)
    owner ||= seller
    create(:seller_transfer, seller: owner, amount: 40, status: status,
                             order: create(:order, store: owner.store, seller: owner))
  end

  # An earning the provider never accepted is counted in no balance and
  # collected by no settlement, and the hooks that retry one fire when a seller
  # *becomes* payable — which never happens again for a seller who was payable
  # all along. This job is the only thing that revisits them.
  it 'hands a seller with a refused earning to a job of their own' do
    earning(status: 'processing')

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id)
  end

  it 'hands over one whose earning was never sent at all' do
    earning(status: 'pending')

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id)
  end

  # Confirming an earning is not settling it, so the seller's settlement
  # schedule has no bearing here: an operator paying by hand still has to see
  # what they owe.
  it 'hands over a seller the marketplace settles by hand' do
    seller.update!(payouts_schedule_interval: 'manual')
    earning(status: 'processing')

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id)
  end

  # Asking again is how the same money moves twice.
  it 'leaves an earning nobody can account for alone' do
    earning(status: 'unresolved')

    described_class.perform_now

    expect(enqueued_seller_ids).to be_empty
  end

  it 'says nothing when every earning is confirmed' do
    earning(status: 'completed')

    described_class.perform_now

    expect(enqueued_seller_ids).to be_empty
  end

  # A settlement has already claimed it, so it is not the provider that is
  # owed a call.
  it 'ignores an earning a settlement holds' do
    earning(status: 'pending').update!(payout: create(:seller_payout, seller: seller))

    described_class.perform_now

    expect(enqueued_seller_ids).to be_empty
  end

  it 'ignores a seller who is not approved' do
    pending_seller = create(:seller, store: store, status: 'pending')
    earning(status: 'processing', owner: pending_seller)

    described_class.perform_now

    expect(enqueued_seller_ids).to be_empty
  end

  it 'reaches sellers across every store' do
    earning(status: 'processing')
    other_seller = create(:seller, :approved, store: create(:store))
    earning(status: 'processing', owner: other_seller)

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id, other_seller.id)
  end

  # The job would return at once, and a marketplace's half-onboarded sellers
  # are a standing population against a job that runs often. Nothing is lost:
  # finishing onboarding runs the job for them directly.
  context 'when the provider will not accept the seller yet' do
    before { allow(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true) }

    it 'passes over them' do
      seller.update!(payouts_enabled_at: nil)
      earning(status: 'processing')

      described_class.perform_now

      expect(enqueued_seller_ids).to be_empty
    end

    it 'hands over one the provider has since accepted' do
      seller.update!(payouts_enabled_at: Time.current)
      earning(status: 'processing')

      described_class.perform_now

      expect(enqueued_seller_ids).to contain_exactly(seller.id)
    end
  end
end
