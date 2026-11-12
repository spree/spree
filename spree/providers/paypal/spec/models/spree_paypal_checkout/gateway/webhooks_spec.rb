require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway::Webhooks do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, :with_webhook, store: store) }
  let(:cart) { create(:cart_with_line_items, store: store) }
  let!(:payment_session) do
    create(:paypal_checkout_payment_session, owner: cart, payment_method: gateway, external_id: 'ORDER1234567890AB')
  end
  let(:client) { instance_double(SpreePaypalCheckout::NotificationsClient) }
  let(:headers) do
    {
      'HTTP_PAYPAL_AUTH_ALGO' => 'SHA256withRSA',
      'HTTP_PAYPAL_CERT_URL' => 'https://api.sandbox.paypal.com/v1/notifications/certs/CERT-1',
      'HTTP_PAYPAL_TRANSMISSION_ID' => 'transmission-1',
      'HTTP_PAYPAL_TRANSMISSION_SIG' => 'signature',
      'HTTP_PAYPAL_TRANSMISSION_TIME' => '2026-10-29T10:00:00Z'
    }
  end

  def event_body(event_type, order_id: 'ORDER1234567890AB')
    {
      id: 'WH-EVENT-1',
      event_type: event_type,
      resource: { id: 'CAPTURE123456789A', supplementary_data: { related_ids: { order_id: order_id } } }
    }.to_json
  end

  before do
    allow(gateway).to receive(:notifications_client).and_return(client)
    allow(client).to receive(:verify_webhook_signature).and_return('SUCCESS')
  end

  it 'subscribes to exactly the events it handles' do
    expect(described_class::SUPPORTED_EVENTS).to contain_exactly(
      'PAYMENT.CAPTURE.COMPLETED', 'PAYMENT.CAPTURE.PENDING', 'PAYMENT.AUTHORIZATION.CREATED',
      'PAYMENT.CAPTURE.DENIED', 'PAYMENT.CAPTURE.DECLINED'
    )
  end

  describe '#parse_webhook_event' do
    {
      'PAYMENT.CAPTURE.COMPLETED' => :captured,
      'PAYMENT.CAPTURE.PENDING' => :authorized,
      'PAYMENT.AUTHORIZATION.CREATED' => :authorized,
      'PAYMENT.CAPTURE.DENIED' => :failed,
      'PAYMENT.CAPTURE.DECLINED' => :failed
    }.each do |event_type, action|
      it "translates #{event_type} into #{action} for the order's session" do
        expect(gateway.parse_webhook_event(event_body(event_type), headers)).to eq(
          action: action, payment_session: payment_session
        )
      end
    end

    it 'sends the delivery, its signature headers and the webhook id to PayPal' do
      body = event_body('PAYMENT.CAPTURE.COMPLETED')
      gateway.parse_webhook_event(body, headers)

      expect(client).to have_received(:verify_webhook_signature).with(
        raw_body: body,
        webhook_id: 'WH-TEST-1234567890',
        headers: {
          auth_algo: 'SHA256withRSA',
          cert_url: 'https://api.sandbox.paypal.com/v1/notifications/certs/CERT-1',
          transmission_id: 'transmission-1',
          transmission_sig: 'signature',
          transmission_time: '2026-10-29T10:00:00Z'
        }
      )
    end

    %w[CHECKOUT.ORDER.APPROVED PAYMENT.CAPTURE.REFUNDED PAYMENT.CAPTURE.REVERSED].each do |event_type|
      it "ignores #{event_type}" do
        expect(gateway.parse_webhook_event(event_body(event_type), headers)).to be_nil
      end
    end

    it 'ignores an order it has no session for' do
      expect(gateway.parse_webhook_event(event_body('PAYMENT.CAPTURE.COMPLETED', order_id: 'OTHERORDER1234567'), headers)).to be_nil
    end

    it "ignores another payment method's session" do
      other = create(:paypal_checkout_gateway, :with_webhook, store: store)
      allow(other).to receive(:notifications_client).and_return(client)

      expect(other.parse_webhook_event(event_body('PAYMENT.CAPTURE.COMPLETED'), headers)).to be_nil
    end

    it 'only translates the event' do
      expect { gateway.parse_webhook_event(event_body('PAYMENT.CAPTURE.COMPLETED'), headers) }.
        not_to(change { [payment_session.reload.status, Spree::Payment.count] })
    end

    context 'when verification fails' do
      def parse(body = event_body('PAYMENT.CAPTURE.COMPLETED'), with_headers = headers)
        gateway.parse_webhook_event(body, with_headers)
      end

      it 'rejects a signature PayPal does not confirm' do
        allow(client).to receive(:verify_webhook_signature).and_return('FAILURE')

        expect { parse }.to raise_error(Spree::PaymentMethod::WebhookSignatureError, 'Invalid webhook signature')
      end

      it 'rejects every delivery while no webhook id is stored, in every environment' do
        gateway.preferred_webhook_id = nil

        expect { parse }.to raise_error(Spree::PaymentMethod::WebhookSignatureError, /not registered/)
        expect(client).not_to have_received(:verify_webhook_signature)
      end

      it 'rejects a malformed body' do
        expect { parse('{not json') }.to raise_error(Spree::PaymentMethod::WebhookSignatureError, 'Malformed webhook payload')
      end

      it 'rejects a delivery without the signature headers' do
        expect { parse(event_body('PAYMENT.CAPTURE.COMPLETED'), headers.except('HTTP_PAYPAL_TRANSMISSION_SIG')) }.
          to raise_error(Spree::PaymentMethod::WebhookSignatureError, 'Missing PayPal signature headers')
      end

      it 'rejects a delivery when PayPal cannot be reached' do
        allow(client).to receive(:verify_webhook_signature).and_raise(Net::ReadTimeout)

        expect { parse }.to raise_error(Spree::PaymentMethod::WebhookSignatureError, /could not verify/)
      end

      it 'rejects a delivery when PayPal answers with an error' do
        allow(client).to receive(:verify_webhook_signature).
          and_raise(SpreePaypalCheckout::NotificationsClient::Error, 'PayPal answered 500')

        expect { parse }.to raise_error(Spree::PaymentMethod::WebhookSignatureError, /could not verify/)
      end
    end
  end

  describe 'registration' do
    include ActiveJob::TestHelper

    it 'is queued when a method is created' do
      expect { create(:paypal_checkout_gateway, store: store) }.
        to have_enqueued_job(SpreePaypalCheckout::RegisterWebhookJob)
    end

    it 'is queued when the credentials change' do
      gateway

      expect { gateway.update!(preferred_client_secret: 'rotated') }.
        to have_enqueued_job(SpreePaypalCheckout::RegisterWebhookJob).with(gateway.id)
    end

    it 'is queued when test mode changes' do
      gateway

      expect { gateway.update!(preferred_test_mode: false) }.to have_enqueued_job(SpreePaypalCheckout::RegisterWebhookJob)
    end

    it 'is not queued when registration stores the webhook id' do
      gateway

      expect { gateway.update!(preferred_webhook_id: 'WH-NEW') }.not_to have_enqueued_job(SpreePaypalCheckout::RegisterWebhookJob)
    end

    it 'is not queued for an unrelated change' do
      gateway

      expect { gateway.update!(name: 'PayPal (renamed)') }.not_to have_enqueued_job(SpreePaypalCheckout::RegisterWebhookJob)
    end
  end
end
