require 'spec_helper'

RSpec.describe Spree::DataRequests::ProcessJob do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:data_request) { create(:data_request, store: store, customer: customer, email: customer.email) }

  # Named rather than left on the default: an export reads a person's whole
  # history and a statutory clock is running on it, so a shop with a long
  # import backlog can give these their own workers without repointing
  # everything else.
  it 'runs on the data requests queue' do
    expect(described_class.new.queue_name).to eq(Spree.queues.data_requests.to_s)
  end

  it 'fulfills the request' do
    described_class.perform_now(data_request.prefixed_id)

    expect(data_request.reload).to be_completed
  end

  # A request left in `processing` would block the subject from asking again,
  # because a pending request is what rate-limits them.
  it 'records a failure rather than leaving the request mid-flight' do
    allow(Spree::DataRequests::Fulfill).to receive(:call).and_raise(StandardError, 'boom')

    expect { described_class.perform_now(data_request.prefixed_id) }.to raise_error(StandardError)
    expect(data_request.reload).to be_failed
  end
end
