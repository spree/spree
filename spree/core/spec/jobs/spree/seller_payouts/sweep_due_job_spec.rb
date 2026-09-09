require 'spec_helper'

RSpec.describe Spree::SellerPayouts::SweepDueJob do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def enqueued_seller_ids
    enqueued_jobs.
      select { |job| job[:job] == Spree::SellerPayouts::SweepSellerJob }.
      map { |job| job[:args].first }
  end

  it 'hands an approved seller to a job of their own' do
    seller

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id)
  end

  it 'ignores a seller who is not approved' do
    create(:seller, store: store, status: 'pending')

    described_class.perform_now

    expect(enqueued_seller_ids).to be_empty
  end

  # Every marketplace on the installation is swept, each seller reached
  # through the store that owns them.
  it 'reaches sellers across every store' do
    seller
    other_seller = create(:seller, :approved, store: create(:store))

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id, other_seller.id)
  end

  # Whether a seller is actually due is the per-seller job's question — this
  # one only fans out, so a settled seller still gets a job that decides to do
  # nothing. Asking here would mean running the interval logic twice.
  it 'leaves the due date to the job it enqueues' do
    create(:seller_payout, seller: seller, currency: 'USD', status: 'completed', amount: 40)

    described_class.perform_now

    expect(enqueued_seller_ids).to contain_exactly(seller.id)
  end

  # A marketplace with many sellers takes long enough to fan out that a deploy
  # can land mid-run, and re-enqueueing every seller already handed off is
  # work a marketplace pays for twice.
  describe 'resuming after an interruption' do
    let(:other_store) { create(:store) }
    let!(:other_seller) { create(:seller, :approved, store: other_store) }

    def run_with_continuation(cursor)
      job = described_class.new
      job.continuation = ActiveJob::Continuation.new(
        job, 'completed' => [], 'current' => ['fan_out', cursor]
      )
      job.perform_now
    end

    it 'skips the stores it already fanned out' do
      seller

      # Resume as though every store up to and including the first had been
      # handed off: the cursor holds the id the run would continue from.
      run_with_continuation(other_store.id)

      expect(enqueued_seller_ids).to contain_exactly(other_seller.id)
    end

    it 'reaches every store when starting fresh' do
      seller

      run_with_continuation(nil)

      expect(enqueued_seller_ids).to contain_exactly(seller.id, other_seller.id)
    end
  end
end
