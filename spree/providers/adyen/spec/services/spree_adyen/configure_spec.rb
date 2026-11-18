require 'spec_helper'

RSpec.describe SpreeAdyen::Configure do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }
  let(:merchant) { gateway.preferred_merchant_account }
  let(:management) { AdyenHelpers::MANAGEMENT_URL }
  let(:webhooks_url) { "#{management}/merchants/#{merchant}/webhooks" }
  let(:credential) { { 'clientKey' => 'test_EXISTINGKEY', 'allowedOrigins' => [] } }

  before do
    allow_any_instance_of(SpreeAdyen::Gateway).to receive(:wait_before_retry)
    stub_request(:get, "#{management}/me").to_return(adyen_json(credential))
    stub_request(:post, "#{management}/me/allowedOrigins").to_return(adyen_json({ 'id' => 'AO1' }))
    stub_request(:get, "#{webhooks_url}?pageSize=100").to_return(adyen_json({ 'data' => [] }))
    stub_request(:post, webhooks_url).to_return(adyen_json({ 'id' => 'WBHKNEW000000001', 'url' => gateway.webhook_url }))
    stub_request(:post, %r{#{webhooks_url}/[^/]+/generateHmac}).to_return(adyen_json({ 'hmacKey' => 'AB' * 32 }))
  end

  it 'keeps the client key the credential already has' do
    described_class.call(gateway)

    expect(gateway.reload.preferred_client_key).to eq('test_EXISTINGKEY')
    expect(a_request(:post, "#{management}/me/generateClientKey")).not_to have_been_made
  end

  it 'generates a client key only when the credential has none' do
    stub_request(:get, "#{management}/me").to_return(adyen_json(credential.merge('clientKey' => nil)))
    stub_request(:post, "#{management}/me/generateClientKey").to_return(adyen_json({ 'clientKey' => 'test_NEWKEY' }))

    described_class.call(gateway)

    expect(gateway.reload.preferred_client_key).to eq('test_NEWKEY')
  end

  it "adds the store's allowed origins, skipping loopback and listed ones" do
    create(:allowed_origin, store: store, origin: 'https://shop.example.com')
    create(:allowed_origin, store: store, origin: 'https://listed.example.com')
    create(:allowed_origin, store: store, origin: 'http://localhost:3001')
    stub_request(:get, "#{management}/me").
      to_return(adyen_json(credential.merge('allowedOrigins' => [{ 'domain' => 'https://listed.example.com' }])))

    described_class.call(gateway)

    expect(a_request(:post, "#{management}/me/allowedOrigins").with(body: { domain: 'https://shop.example.com' }.to_json)).to have_been_made.once
    expect(a_request(:post, "#{management}/me/allowedOrigins")).to have_been_made.once
  end

  it 'treats an origin Adyen already has as done' do
    create(:allowed_origin, store: store, origin: 'https://shop.example.com')
    stub_request(:post, "#{management}/me/allowedOrigins").
      to_return(adyen_json({ 'status' => 422, 'detail' => 'Allowed origin already exists' }, status: 422))

    expect { described_class.call(gateway) }.not_to raise_error
  end

  it "creates the method's webhook and its HMAC key" do
    described_class.call(gateway)

    expect(a_request(:post, webhooks_url).with(body: hash_including('type' => 'standard', 'url' => gateway.webhook_url))).to have_been_made
    expect(gateway.reload).to have_attributes(preferred_webhook_id: 'WBHKNEW000000001', preferred_hmac_key: 'AB' * 32)
  end

  it 'finds the standard webhook already on the URL' do
    stub_request(:get, "#{webhooks_url}?pageSize=100").
      to_return(adyen_json({ 'data' => [{ 'id' => 'WBHKFOUND0000001', 'type' => 'standard', 'url' => gateway.webhook_url }] }))

    described_class.call(gateway)

    expect(a_request(:post, webhooks_url)).not_to have_been_made
    expect(gateway.reload.preferred_webhook_id).to eq('WBHKFOUND0000001')
  end

  it 'moves a stored webhook pointing elsewhere in place, keeping its key' do
    gateway.update!(preferred_webhook_id: 'WBHKLEGACY000001', preferred_hmac_key: 'CD' * 32)
    stub_request(:get, "#{webhooks_url}/WBHKLEGACY000001").
      to_return(adyen_json({ 'id' => 'WBHKLEGACY000001', 'url' => 'https://shop.example.com/adyen/webhooks' }))
    update = stub_request(:patch, "#{webhooks_url}/WBHKLEGACY000001").with(body: { url: gateway.webhook_url }.to_json).
             to_return(adyen_json({ 'id' => 'WBHKLEGACY000001' }))

    described_class.call(gateway)

    expect(update).to have_been_requested
    expect(gateway.reload).to have_attributes(preferred_webhook_id: 'WBHKLEGACY000001', preferred_hmac_key: 'CD' * 32)
    expect(a_request(:post, /generateHmac/)).not_to have_been_made
  end

  it 'keeps the old key as the previous one when a new webhook gets a new key' do
    gateway.update!(preferred_webhook_id: 'WBHKGONE00000001', preferred_hmac_key: 'CD' * 32)
    stub_request(:get, "#{webhooks_url}/WBHKGONE00000001").to_return(adyen_json({ 'status' => 404, 'detail' => 'Webhook not found' }, status: 404))

    described_class.call(gateway)

    expect(gateway.reload).to have_attributes(preferred_hmac_key: 'AB' * 32, preferred_previous_hmac_key: 'CD' * 32,
                                              preferred_webhook_id: 'WBHKNEW000000001')
  end

  # Recorded against the test account by the author (Phase 15).
  describe 'against Adyen', :vcr do
    before { WebMock.reset! }

    it 'configures a fresh credential', vcr: { cassette_name: 'configure_fresh' } do
      described_class.call(gateway)

      expect(gateway.reload).to have_attributes(preferred_client_key: be_present, preferred_hmac_key: be_present, preferred_webhook_id: be_present)
    end

    it 'finds what is already in place', vcr: { cassette_name: 'configure_existing' } do
      described_class.call(gateway)

      expect(gateway.reload.preferred_webhook_id).to be_present
    end

    it 'moves a legacy webhook to the 6.0 URL', vcr: { cassette_name: 'configure_legacy_webhook_url' } do
      gateway.update!(preferred_webhook_id: ENV.fetch('ADYEN_LEGACY_WEBHOOK_ID', 'WBHK42CX922322CM5QBDFDT99T3T6K'), preferred_hmac_key: 'EF' * 32)

      described_class.call(gateway)

      expect(gateway.reload.preferred_hmac_key).to eq('EF' * 32)
    end
  end
end
