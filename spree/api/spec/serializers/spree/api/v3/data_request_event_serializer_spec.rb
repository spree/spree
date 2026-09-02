require 'spec_helper'

RSpec.describe Spree::Api::V3::DataRequestEventSerializer do
  let(:store) { @default_store }
  let(:data_request) { create(:data_request, store: store) }

  before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

  # A webhook payload reaches every subscribed endpoint and is persisted in
  # the delivery log, which the Admin API serves back. The download link is an
  # unauthenticated credential for a person's entire personal-data export, so
  # it must never travel that way.
  it 'keeps the download credential out of the event payload' do
    payload = data_request.reload.event_payload

    expect(payload).not_to have_key('download_url')
    expect(payload.to_s).not_to include(data_request.download_token)
  end

  it 'still says which request finished and how' do
    payload = data_request.reload.event_payload

    expect(payload).to include('number', 'kind', 'status', 'completed_at')
  end

  it 'is what the model publishes, not the store serializer' do
    expect(data_request.event_serializer_class).to eq(described_class)
  end
end
