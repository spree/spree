require 'spec_helper'

RSpec.describe SpreeStripe::CreateGatewayWebhooks do
  subject { described_class.new.call(payment_method: payment_method) }

  let(:store) { @default_store }
  let(:payment_method) { create(:stripe_gateway, store: store) }
  let(:webhook_url) { 'https://spreecommerce.org/stripe/' }

  let(:stripe_webhooks) { Stripe::WebhookEndpoint.list({ limit: 100 }, payment_method.api_options)[:data] }
  let(:spree_webhook_endpoints) { stripe_webhooks.select { |webhook| webhook[:url] == webhook_url } }
  let(:stripe_webhook) { spree_webhook_endpoints.first }

  before { allow(payment_method).to receive(:webhook_url).and_return(webhook_url) }

  it 'creates a webhook endpoint and stores its credentials on the gateway', vcr: { cassette_name: 'create_gateway_webhooks' } do
    subject

    expect(stripe_webhook.enabled_events).to match_array(SpreeStripe::Gateway::Webhooks::SUPPORTED_EVENTS)
    expect(stripe_webhook.status).to eq('enabled')

    expect(payment_method.reload.preferred_webhook_endpoint_id).to eq(stripe_webhook.id)
    expect(payment_method.preferred_webhook_signing_secret).to eq('<STRIPE_WEBHOOK_SIGNING_SECRET>')
  end

  context 'when the gateway has no webhook url' do
    before { allow(payment_method).to receive(:webhook_url).and_return(nil) }

    it 'does nothing' do
      expect(Stripe::WebhookEndpoint).not_to receive(:list)
      expect(subject).to be_nil
    end
  end

  context 'when a matching endpoint already exists' do
    context 'and the gateway already holds its id and signing secret' do
      before do
        payment_method.update!(
          preferred_webhook_endpoint_id: 'we_1TUq8w2ESifGlJezdHC8YApb',
          preferred_webhook_signing_secret: 'whsec_already_known'
        )
      end

      it 'reuses it without registering a new one', vcr: { cassette_name: 'existing_gateway_webhooks' } do
        expect(Stripe::WebhookEndpoint).not_to receive(:create)
        expect(Stripe::WebhookEndpoint).not_to receive(:delete)

        expect(subject[:id]).to eq('we_1TUq8w2ESifGlJezdHC8YApb')
        expect(payment_method.reload.preferred_webhook_signing_secret).to eq('whsec_already_known')
      end
    end

    # Stripe only reveals the signing secret at creation time, so an endpoint we
    # cannot verify against has to be replaced.
    context 'and the gateway has no signing secret for it' do
      # The recorded endpoint is long gone from the Stripe account, so the
      # deletion is asserted rather than replayed.
      before { allow(Stripe::WebhookEndpoint).to receive(:delete) }

      it 'deletes the stale endpoint and registers a fresh one', vcr: { cassette_name: 'create_another_gateway_webhooks' } do
        subject

        expect(Stripe::WebhookEndpoint).to have_received(:delete).
          with('we_1TUq8w2ESifGlJezdHC8YApb', {}, payment_method.api_options)

        expect(payment_method.reload.preferred_webhook_endpoint_id).to eq('we_1TUq8x2ESifGlJezmllQ9fRC')
        expect(payment_method.preferred_webhook_signing_secret).to eq('<STRIPE_WEBHOOK_SIGNING_SECRET>')
      end
    end
  end
end
