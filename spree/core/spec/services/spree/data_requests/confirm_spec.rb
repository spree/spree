require 'spec_helper'

RSpec.describe Spree::DataRequests::Confirm do
  let(:store) { @default_store }
  let(:data_request) { create(:data_request, :awaiting_confirmation, store: store) }

  subject(:result) { described_class.call(data_request: data_request) }

  it 'opens the request and queues the work' do
    expect { result }.to have_enqueued_job(Spree::DataRequests::ProcessJob).with(data_request.prefixed_id)
    expect(result).to be_success
    expect(data_request.reload).to be_pending
  end

  it 'changes nothing when the link is followed again' do
    described_class.call(data_request: data_request)

    expect { result }.not_to have_enqueued_job(Spree::DataRequests::ProcessJob)
    expect(result).to be_success
  end

  it 'refuses a request left unconfirmed past the window' do
    data_request.update_columns(requested_at: (Spree::DataRequest::CONFIRMATION_WINDOW + 1.minute).ago)

    expect { result }.not_to have_enqueued_job(Spree::DataRequests::ProcessJob)
    expect(result).to be_failure
    expect(data_request.reload).to be_lapsed
  end
end
