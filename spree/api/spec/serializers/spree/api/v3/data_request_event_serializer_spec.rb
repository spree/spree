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

  # Same credential, a different way out. Listing requests in the admin needs
  # only `read_customers`, while downloading the export asks for four
  # permissions — so rendering the link on those rows would hand the whole
  # file to a role that was never granted it.
  it 'keeps the download credential off the admin payload but leaves the customer theirs' do
    admin = Spree::Api::V3::Admin::DataRequestSerializer.new(data_request.reload).
            serializable_hash.keys.map(&:to_s)
    storefront = Spree::Api::V3::DataRequestSerializer.new(data_request).
                 serializable_hash.keys.map(&:to_s)

    expect(admin).not_to include('download_url')
    expect(storefront).to include('download_url')
  end

  it 'still says which request finished and how' do
    payload = data_request.reload.event_payload

    expect(payload).to include('number', 'kind', 'status', 'completed_at')
  end

  it 'is what the model publishes, not the store serializer' do
    expect(data_request.event_serializer_class).to eq(described_class)
  end

  # What a storefront that sends its own emails needs to ask for confirmation,
  # and still nothing that opens the export.
  it 'gives the confirmation request the token and the page the link opens' do
    payload = data_request.event_payload_for(
      'data_request.confirmation_requested',
      confirmation_token: 'live-token', redirect_url: 'https://shop.example.com/confirm'
    )

    expect(payload).to include('confirmation_token' => 'live-token', 'redirect_url' => 'https://shop.example.com/confirm',
                               'email' => data_request.email, 'store_id' => store.prefixed_id)
    expect(payload.to_s).not_to include(data_request.reload.download_token)
  end
end
