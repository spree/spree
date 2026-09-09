require 'spec_helper'

# Exercises the unified carrier webhook endpoint end to end with EasyPost as
# the provider: signed HTTP in, integration verifies and translates, core
# workflow records the update. Signatures here are real HMACs, not stubs —
# the verification IS the subject.
RSpec.describe 'EasyPost fulfillment webhooks', type: :request do
  let(:store) { @default_store }
  let(:webhook_secret) { 'whsec_test_secret' }

  # Activation verifies connectivity against EasyPost for real; that network
  # call is not this spec's subject.
  before { allow_any_instance_of(SpreeEasyPost::Integration).to receive(:can_connect?).and_return(true) }

  let!(:integration) do
    SpreeEasyPost::Integration.create!(
      store: store,
      active: true,
      preferences: { api_key: 'EZTK-test', webhook_secret: webhook_secret }
    )
  end

  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  let(:delivery) { fulfillment.reload.primary_delivery }

  before do
    fulfillment.deliveries.destroy_all
    Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: 'EZ1000000001')
    Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)
    host! store.url
  end

  def sign(body, secret: webhook_secret)
    normalized = secret.unicode_normalize(:nfkd).encode('utf-8')
    "hmac-sha256-hex=#{OpenSSL::HMAC.hexdigest('sha256', normalized, body)}"
  end

  def post_tracker(status:, tracking_code: 'EZ1000000001', secret: webhook_secret, **result)
    body = {
      description: 'tracker.updated',
      result: { object: 'Tracker', tracking_code: tracking_code, status: status, carrier: 'USPS' }.merge(result)
    }.to_json

    post "/api/v3/webhooks/fulfillments/#{integration.prefixed_id}",
         params: body,
         headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hmac-Signature' => sign(body, secret: secret) }
  end

  it 'records the carrier update on the consignment' do
    post_tracker(status: 'out_for_delivery')

    expect(response).to have_http_status(:ok)
    expect(delivery.reload.status).to eq('out_for_delivery')
    expect(fulfillment.reload).to be_fulfilled
  end

  it 'confirms receipt when the carrier reports delivery' do
    post_tracker(
      status: 'delivered',
      tracking_details: [{ status: 'delivered', datetime: '2026-08-13T14:20:00Z' }]
    )

    expect(fulfillment.reload).to be_delivered
    expect(fulfillment.delivered_at).to eq(Time.utc(2026, 8, 13, 14, 20))
  end

  it 'records a bounce without moving the fulfillment backwards' do
    post_tracker(status: 'return_to_sender')

    expect(delivery.reload.status).to eq('return_to_sender')
    expect(fulfillment.reload).to be_fulfilled
  end

  describe 'signature verification' do
    it 'refuses a wrong signature without touching anything' do
      post_tracker(status: 'delivered', secret: 'not-the-secret')

      expect(response).to have_http_status(:unauthorized)
      expect(delivery.reload.status).to eq('pending')
    end

    it 'refuses an unsigned request' do
      body = { description: 'tracker.updated', result: { tracking_code: 'EZ1000000001', status: 'delivered' } }.to_json

      post "/api/v3/webhooks/fulfillments/#{integration.prefixed_id}",
           params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    # A merchant who never configured the secret gets a closed endpoint, not
    # an open one — an unauthenticated delivery report would start the return
    # window and the EU withdrawal clock.
    it 'refuses everything while no secret is configured' do
      integration.update!(preferences: integration.preferences.merge(webhook_secret: nil))

      post_tracker(status: 'delivered', secret: 'anything')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'payloads it acknowledges without acting' do
    it 'accepts an unknown tracking code' do
      expect {
        post_tracker(status: 'delivered', tracking_code: 'EZ_NOT_OURS')
      }.not_to change { fulfillment.reload.status }

      expect(response).to have_http_status(:ok)
    end

    it 'accepts a non-tracker event' do
      body = { description: 'batch.created', result: {} }.to_json

      post "/api/v3/webhooks/fulfillments/#{integration.prefixed_id}",
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hmac-Signature' => sign(body) }

      expect(response).to have_http_status(:ok)
    end
  end

  # A tracking code can never address another tenant's parcel: the delivery
  # is resolved inside the verified integration's own store.
  it 'ignores a consignment belonging to another store' do
    other_fulfillment = create(:order_ready_to_ship, store: create(:store, code: "other-#{SecureRandom.hex(4)}")).fulfillments.first
    other_fulfillment.deliveries.destroy_all
    Spree::Deliveries::Create.new.call(owner: other_fulfillment, tracking_number: 'EZ_OTHER_STORE')

    post_tracker(status: 'delivered', tracking_code: 'EZ_OTHER_STORE')

    expect(response).to have_http_status(:ok)
    expect(other_fulfillment.reload.primary_delivery.status).to eq('pending')
  end

  it 'answers 404 for an unknown integration' do
    body = { description: 'tracker.updated', result: {} }.to_json

    post '/api/v3/webhooks/fulfillments/int_doesnotexist',
         params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:not_found)
  end

  it 'ignores an inactive integration' do
    integration.update!(active: false)

    post_tracker(status: 'delivered')

    expect(response).to have_http_status(:not_found)
  end
end
