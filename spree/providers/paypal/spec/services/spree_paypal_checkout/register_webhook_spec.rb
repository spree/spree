require 'spec_helper'

RSpec.describe SpreePaypalCheckout::RegisterWebhook do
  subject(:register) { described_class.new.call(payment_method: gateway) }

  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store) }
  let(:client) { instance_double(SpreePaypalCheckout::NotificationsClient) }
  let(:events) { SpreePaypalCheckout::Gateway::Webhooks::SUPPORTED_EVENTS }

  before { allow(gateway).to receive(:notifications_client).and_return(client) }

  context 'when PayPal has no webhook for the URL' do
    before do
      allow(client).to receive(:list_webhooks).and_return([{ 'id' => 'WH-OTHER', 'url' => 'https://other.example/hook' }])
      allow(client).to receive(:create_webhook).and_return({ 'id' => 'WH-NEW' })
    end

    it "creates one subscribed to the gem's events and stores its id" do
      register

      expect(client).to have_received(:create_webhook).with(url: gateway.webhook_url, event_types: events)
      expect(gateway.reload.preferred_webhook_id).to eq('WH-NEW')
    end
  end

  context 'when PayPal has a webhook for the URL' do
    let(:subscribed) { ['CHECKOUT.ORDER.APPROVED'] }

    before do
      allow(client).to receive(:list_webhooks).and_return(
        [{ 'id' => 'WH-EXISTING', 'url' => gateway.webhook_url, 'event_types' => subscribed.map { |name| { 'name' => name } } }]
      )
      allow(client).to receive(:replace_webhook_events).and_return({ 'id' => 'WH-EXISTING' })
      allow(client).to receive(:create_webhook)
    end

    it "replaces its events with the gem's and stores its id" do
      register

      expect(client).to have_received(:replace_webhook_events).with('WH-EXISTING', events)
      expect(client).not_to have_received(:create_webhook)
      expect(gateway.reload.preferred_webhook_id).to eq('WH-EXISTING')
    end

    context "that is already subscribed to the gem's events" do
      let(:subscribed) { events.reverse }

      it 'keeps it without asking PayPal for a change and stores its id' do
        expect(register['id']).to eq('WH-EXISTING')
        expect(client).not_to have_received(:replace_webhook_events)
        expect(client).not_to have_received(:create_webhook)
        expect(gateway.reload.preferred_webhook_id).to eq('WH-EXISTING')
      end
    end
  end

  it 'does nothing without a webhook URL' do
    allow(gateway).to receive(:webhook_url).and_return(nil)
    allow(client).to receive(:list_webhooks)

    expect(register).to be_nil
    expect(client).not_to have_received(:list_webhooks)
  end

  context 'against PayPal' do
    # PayPal only takes a public https URL; PAYPAL_WEBHOOK_URL names one.
    before do
      allow(gateway).to receive(:notifications_client).and_call_original
      allow(gateway).to receive(:webhook_url).and_return(ENV.fetch('PAYPAL_WEBHOOK_URL', 'https://spree-paypal.example.com/api/v3/webhooks/payments/pm_test'))
    end

    it 'creates a webhook', vcr: { cassette_name: 'register_webhook_new' } do
      expect(register['id']).to be_present
      expect(gateway.reload.preferred_webhook_id).to eq(register['id'])
    end

    it "replaces an existing webhook's events", vcr: { cassette_name: 'register_webhook_existing' } do
      webhook = register

      expect(webhook['event_types'].map { |event| event['name'] }).to match_array(events)
    end
  end
end
