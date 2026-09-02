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

  it 'treats access and erasure as different requests' do
    described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS)

    erasure = described_class.call(store: store, customer: customer, kind: Spree::DataRequest::ERASURE)

    expect(erasure.value).to be_erasure
  end
end
