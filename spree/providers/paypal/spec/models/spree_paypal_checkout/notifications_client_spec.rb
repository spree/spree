require 'spec_helper'

RSpec.describe SpreePaypalCheckout::NotificationsClient do
  subject(:client) { described_class.new(gateway) }

  let(:gateway) { create(:paypal_checkout_gateway, :with_webhook) }
  let(:base) { 'https://api-m.sandbox.paypal.com' }

  before do
    allow(gateway).to receive(:request_access_token).and_return(double(access_token: 'A21AAtoken'))
  end

  describe '#verify_webhook_signature' do
    let(:raw_body) { '{"id":"WH-EVENT-1","event_type":"PAYMENT.CAPTURE.COMPLETED","resource":{"amount":{"value":"10.00"}}}' }
    let(:signature) do
      { auth_algo: 'SHA256withRSA', cert_url: 'https://cert', transmission_id: 't-1', transmission_sig: 'sig', transmission_time: 'now' }
    end

    it 'posts the event as delivered, with the bearer token from the SDK, and returns the verdict' do
      stub = stub_request(:post, "#{base}/v1/notifications/verify-webhook-signature").
             with(headers: { 'Authorization' => 'Bearer A21AAtoken' }) { |request|
               request.body.end_with?(%(,"webhook_event":#{raw_body}})) &&
                 JSON.parse(request.body)['webhook_id'] == 'WH-TEST-1234567890'
             }.
             to_return(status: 200, body: { verification_status: 'SUCCESS' }.to_json)

      expect(client.verify_webhook_signature(raw_body: raw_body, headers: signature, webhook_id: 'WH-TEST-1234567890')).
        to eq('SUCCESS')
      expect(stub).to have_been_requested
    end

    it 'raises naming the status when PayPal answers with an error' do
      stub_request(:post, "#{base}/v1/notifications/verify-webhook-signature").
        to_return(status: 400, body: { name: 'VALIDATION_ERROR', message: 'Invalid request' }.to_json)

      expect { client.verify_webhook_signature(raw_body: '{}', headers: signature, webhook_id: 'WH-1') }.
        to raise_error(described_class::Error, 'PayPal answered 400: VALIDATION_ERROR — Invalid request')
    end

    it 'lets a timeout through for the caller to treat as unverified' do
      stub_request(:post, "#{base}/v1/notifications/verify-webhook-signature").to_timeout

      expect { client.verify_webhook_signature(raw_body: '{}', headers: signature, webhook_id: 'WH-1') }.
        to raise_error(Net::OpenTimeout)
    end

    it 'uses short timeouts' do
      expect(described_class::OPEN_TIMEOUT).to be <= 5
      expect(described_class::READ_TIMEOUT).to be <= 10
    end

    context 'against PayPal' do
      # Recording needs the headers and body of a real sandbox delivery (the
      # webhook simulator's events never verify), in PAYPAL_WEBHOOK_HEADERS
      # (JSON of the five values) and PAYPAL_WEBHOOK_BODY, and the receiving
      # webhook's id in PAYPAL_WEBHOOK_ID.
      let(:recorded_headers) { JSON.parse(ENV.fetch('PAYPAL_WEBHOOK_HEADERS', signature.to_json)).symbolize_keys }
      let(:recorded_body) { ENV.fetch('PAYPAL_WEBHOOK_BODY', raw_body) }
      let(:webhook_id) { ENV.fetch('PAYPAL_WEBHOOK_ID', 'WH-TEST-1234567890') }

      before { allow(gateway).to receive(:request_access_token).and_call_original }

      it 'confirms a genuine delivery', vcr: { cassette_name: 'verify_webhook_signature_valid' } do
        expect(client.verify_webhook_signature(raw_body: recorded_body, headers: recorded_headers, webhook_id: webhook_id)).
          to eq('SUCCESS')
      end

      it 'refuses an altered delivery', vcr: { cassette_name: 'verify_webhook_signature_invalid' } do
        altered = recorded_body.sub('"id":"', '"id":"X')

        expect(client.verify_webhook_signature(raw_body: altered, headers: recorded_headers, webhook_id: webhook_id)).
          to eq('FAILURE')
      end
    end
  end

  describe '#list_webhooks' do
    it 'returns the webhooks' do
      stub_request(:get, "#{base}/v1/notifications/webhooks").
        to_return(status: 200, body: { webhooks: [{ id: 'WH-1', url: 'https://shop.example/hook' }] }.to_json)

      expect(client.list_webhooks).to eq([{ 'id' => 'WH-1', 'url' => 'https://shop.example/hook' }])
    end
  end

  describe '#create_webhook' do
    it 'subscribes the URL to the given events' do
      stub = stub_request(:post, "#{base}/v1/notifications/webhooks").
             with(body: { url: 'https://shop.example/hook', event_types: [{ name: 'PAYMENT.CAPTURE.COMPLETED' }] }.to_json).
             to_return(status: 201, body: { id: 'WH-1' }.to_json)

      expect(client.create_webhook(url: 'https://shop.example/hook', event_types: ['PAYMENT.CAPTURE.COMPLETED'])).
        to eq('id' => 'WH-1')
      expect(stub).to have_been_requested
    end
  end

  describe '#replace_webhook_events' do
    it 'replaces the whole event list' do
      stub = stub_request(:patch, "#{base}/v1/notifications/webhooks/WH-1").
             with(body: [{ op: 'replace', path: '/event_types', value: [{ name: 'PAYMENT.CAPTURE.COMPLETED' }] }].to_json).
             to_return(status: 200, body: { id: 'WH-1' }.to_json)

      client.replace_webhook_events('WH-1', ['PAYMENT.CAPTURE.COMPLETED'])

      expect(stub).to have_been_requested
    end
  end

  it 'talks to the live site outside test mode' do
    gateway.preferred_test_mode = false
    stub = stub_request(:get, 'https://api-m.paypal.com/v1/notifications/webhooks').to_return(status: 200, body: '{}')

    client.list_webhooks

    expect(stub).to have_been_requested
  end
end
