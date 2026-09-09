require 'spec_helper'

RSpec.describe Spree::DataRequests::Create do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }

  subject(:result) { described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS) }

  it 'opens the request' do
    expect(result).to be_success
    expect(result.value).to be_a(Spree::DataRequest)
    expect(result.value).to be_pending
  end

  it 'queues the work rather than doing it inline' do
    expect { result }.to have_enqueued_job(Spree::DataRequests::ProcessJob)
  end

  it 'records who it is about' do
    expect(result.value.email).to eq(customer.email)
    expect(result.value.customer).to eq(customer)
  end

  describe 'a second request while one is in flight' do
    let!(:existing) { described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS).value }

    it 'returns the request already being worked on' do
      expect(result.value).to eq(existing)
    end

    it 'does not queue a second build' do
      expect { result }.not_to have_enqueued_job(Spree::DataRequests::ProcessJob)
    end
  end

  describe 'once the earlier request has finished' do
    before do
      described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS).
        value.update!(status: 'completed', completed_at: Time.current)
    end

    it 'lets the customer ask again' do
      expect(result.value).to be_pending
      expect(Spree::DataRequest.where(customer_id: customer.id).count).to eq(2)
    end
  end

  describe 'a customer whose data has already been erased' do
    before { Spree::Customers::Anonymize.call(customer: customer, store: store) }

    it 'refuses the request rather than exporting the tombstone' do
      expect(result).to be_failure
    end

    it 'queues nothing' do
      expect { result }.not_to have_enqueued_job(Spree::DataRequests::ProcessJob)
    end
  end

  # Real threads on a real connection each: the check-then-create window is
  # invisible to sequential calls, because the second one returns from the
  # in-flight check before the race can happen. SQLite serializes writes, so
  # this proves the lock is taken rather than proving it is needed.
  it 'opens one request when two callers race', :db_threads do
    barrier = Concurrent::CyclicBarrier.new(2)

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait
          described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS)
        end
      end
    end
    threads.each(&:join)

    requests = Spree::DataRequest.where(customer_id: customer.id, kind: Spree::DataRequest::ACCESS)

    expect(requests.count).to eq(1)
  end

  it 'treats access and erasure as different requests' do
    described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS)

    erasure = described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ERASURE)

    expect(erasure.value).to be_erasure
  end

  # A staff export opens its own row and answers it inline. That row is not the
  # customer's request, so it must not stand in for one: handing it back would
  # close their request with a file they can never download.
  it 'does not hand back a request a staff member opened' do
    staff_row = Spree::DataRequest.create!(
      store: store, customer: customer, kind: Spree::DataRequest::ACCESS,
      email: customer.email, requested_by: create(:admin_user)
    )

    result = described_class.call(store: store, customer: customer,
                                  kind: Spree::DataRequest::ACCESS, process: false)

    expect(result.value).not_to eq(staff_row)
    expect(result.value.requested_by).to be_nil
  end
end
