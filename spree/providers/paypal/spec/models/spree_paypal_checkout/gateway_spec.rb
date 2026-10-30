require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store) }
  let(:order_id) { 'ORDER1234567890AB' }
  let(:money) { Spree::Money.new(BigDecimal('10'), currency: 'USD') }
  let(:gateway_options) { { idempotency_key: 'spree-py_test123' } }

  it 'is registered as a payment method' do
    expect(Rails.application.config.spree.payment_methods).to include(described_class)
  end

  it 'answers paypal_checkout as its api type' do
    expect(described_class.api_type).to eq('paypal_checkout')
  end

  it 'keeps the webhook id internal' do
    expect(gateway.preference_internal(:webhook_id)).to be(true)
  end

  it 'keeps the credentials secret' do
    expect(gateway.preference_type(:client_id)).to eq(:password)
    expect(gateway.preference_type(:client_secret)).to eq(:password)
  end

  it 'starts in test mode' do
    expect(described_class.new.preferred_test_mode).to be(true)
  end

  it 'requires a payment session' do
    expect(gateway.session_required?).to be(true)
    expect(gateway.payment_session_class).to eq(Spree::PaymentSessions::PaypalCheckout)
  end

  it 'saves no payment profiles' do
    expect(gateway.payment_profiles_supported?).to be(false)
  end

  it 'takes money amounts' do
    expect(described_class.accepts_money_amounts).to be(true)
  end

  describe '#available_for_order?' do
    let(:cart) { create(:cart_with_line_items, store: store) }

    it 'is true for a currency PayPal takes' do
      expect(gateway.available_for_order?(cart)).to be(true)
    end

    it 'is false for a currency PayPal does not take' do
      cart.update_columns(currency: 'INR')

      expect(gateway.available_for_order?(cart)).to be(false)
    end

    it 'is false for a total PayPal would refuse' do
      cart.update_columns(currency: 'TWD', total: BigDecimal('1234.50'))

      expect(gateway.available_for_order?(cart)).to be(false)
    end
  end

  describe '#paypal_intent' do
    it 'captures for a method that captures at checkout' do
      gateway.update!(capture_method: 'checkout')

      expect(gateway.paypal_intent).to eq('CAPTURE')
    end

    it 'authorizes for a method that captures on dispatch' do
      gateway.update!(capture_method: 'on_dispatch')

      expect(gateway.paypal_intent).to eq('AUTHORIZE')
    end

    it 'authorizes for a method captured by hand' do
      gateway.update!(capture_method: 'manual')

      expect(gateway.paypal_intent).to eq('AUTHORIZE')
    end
  end

  describe '#client' do
    subject(:config) { gateway.client.config }

    it 'talks to the sandbox in test mode' do
      expect(config.environment).to eq(PaypalServerSdk::Environment::SANDBOX)
    end

    it 'talks to the live site otherwise' do
      gateway.preferred_test_mode = false

      expect(config.environment).to eq(PaypalServerSdk::Environment::PRODUCTION)
    end

    it 'times out after 30 seconds and retries GET, POST and PATCH twice' do
      expect(config.timeout).to eq(30)
      expect(config.max_retries).to eq(2)
      expect(config.retry_methods).to eq(%i[get post patch])
      expect(config.retry_statuses).to eq([408, 413, 429, 500, 502, 503, 504, 521, 522, 524])
    end

    it 'never logs bodies or headers' do
      logging = config.logging_configuration

      expect(logging.request_logging_config.log_body).to be(false)
      expect(logging.request_logging_config.log_headers).to be(false)
      expect(logging.response_logging_config.log_body).to be(false)
      expect(logging.response_logging_config.log_headers).to be(false)
    end

    it 'logs at the level PAYPAL_LOG_LEVEL sets' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('PAYPAL_LOG_LEVEL', 'info').and_return('debug')

      expect(config.logging_configuration.log_level).to eq(Logger::DEBUG)
    end

    it 'is rebuilt when the credentials change' do
      first = gateway.client
      gateway.preferred_client_secret = 'rotated'

      expect(gateway.client).not_to be(first)
    end
  end

  describe 'credential check' do
    before { allow(Rails.env).to receive(:test?).and_return(false) }

    let(:gateway) { build(:paypal_checkout_gateway, store: store) }

    it 'accepts credentials PayPal issues a token for' do
      allow(gateway).to receive(:request_access_token).and_return(double)

      expect(gateway).to be_valid
    end

    it 'names what to fix when the sandbox refuses them' do
      allow(gateway).to receive(:request_access_token).and_raise(paypal_error('invalid_client', status: 401))

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base]).to eq(
        ['PayPal sandbox rejected this client id and secret — check that Test mode matches the credentials.']
      )
    end

    it 'names the live site when test mode is off' do
      gateway.preferred_test_mode = false
      allow(gateway).to receive(:request_access_token).and_raise(paypal_error('invalid_client', status: 401))

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base].first).to start_with('PayPal live rejected')
    end

    it 'says PayPal could not be reached when it does not answer' do
      allow(gateway).to receive(:request_access_token).and_raise(Faraday::ConnectionFailed, 'refused')

      expect(gateway).not_to be_valid
      expect(gateway.errors[:base]).to eq(['PayPal could not be reached to check the client id and secret. Try again later.'])
    end

    it 'is not asked again when the credentials did not change' do
      allow(gateway).to receive(:request_access_token).and_return(double)
      gateway.save!
      gateway.name = 'PayPal (renamed)'

      expect(gateway).to be_valid
      expect(gateway).to have_received(:request_access_token).once
    end
  end

  describe 'credential check against PayPal' do
    it 'accepts sandbox credentials', vcr: { cassette_name: 'credentials_valid' } do
      expect(gateway.request_access_token.access_token).to be_present
    end

    it 'reports credentials PayPal rejects', vcr: { cassette_name: 'credentials_rejected' } do
      gateway.preferred_client_id = 'not-a-client-id'
      gateway.preferred_client_secret = 'not-a-secret'

      expect { gateway.request_access_token }.to raise_error(PaypalServerSdk::APIException)
    end
  end

  describe '#gateway_dashboard_payment_url' do
    let(:payment) { build(:payment, payment_method: gateway) }

    it 'links to the capture on the sandbox activity page' do
      payment.metadata = { 'paypal_capture_id' => 'CAPTURE123', 'paypal_authorization_id' => 'AUTH123' }

      expect(gateway.gateway_dashboard_payment_url(payment)).to eq('https://www.sandbox.paypal.com/activity/payment/CAPTURE123')
    end

    it 'links to the authorization when nothing was captured' do
      payment.metadata = { 'paypal_authorization_id' => 'AUTH123' }

      expect(gateway.gateway_dashboard_payment_url(payment)).to eq('https://www.sandbox.paypal.com/activity/payment/AUTH123')
    end

    it 'links to the live site outside test mode' do
      gateway.preferred_test_mode = false
      payment.metadata = { 'paypal_capture_id' => 'CAPTURE123' }

      expect(gateway.gateway_dashboard_payment_url(payment)).to eq('https://www.paypal.com/activity/payment/CAPTURE123')
    end

    it 'has no link without an id' do
      payment.metadata = {}

      expect(gateway.gateway_dashboard_payment_url(payment)).to be_nil
    end
  end

  describe '#authorize and #purchase' do
    let(:order) { create(:order, store: store, total: 10) }
    let!(:payment) { create(:payment, order: order, payment_method: gateway, response_code: order_id, amount: 10) }
    let(:options) { { payment_prefixed_id: payment.prefixed_id } }

    it 'reads back a captured order and answers with its id' do
      allow(gateway).to receive(:paypal_order).with(order_id).
        and_return(paypal_order_data(captures: [paypal_capture]))

      response = gateway.purchase(money, nil, options)

      expect(response).to be_success
      expect(response.authorization).to eq(order_id)
    end

    it 'reads back an authorized order' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(authorizations: [paypal_authorization]))

      expect(gateway.authorize(money, nil, options).authorization).to eq(order_id)
    end

    it 'fails for an order whose only capture was declined' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture(status: 'DECLINED')]))

      expect(gateway.purchase(money, nil, options)).not_to be_success
    end

    it 'fails for an order no money has moved on' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(status: 'APPROVED'))

      expect(gateway.authorize(money, nil, options)).not_to be_success
    end

    it 'fails for a payment it does not know' do
      expect(gateway.authorize(money, nil, { payment_prefixed_id: 'py_unknown' })).not_to be_success
    end
  end

  describe '#capture' do
    subject(:capture) { gateway.capture(money, order_id, gateway_options) }

    context 'with an open authorization' do
      before do
        allow(gateway).to receive(:paypal_order).with(order_id).
          and_return(paypal_order_data(authorizations: [paypal_authorization]))
      end

      it 'captures it as the final capture, keyed on the payment, and answers with the order id' do
        allow(gateway).to receive(:capture_authorization).and_return(paypal_capture)

        expect(capture).to be_success
        expect(capture.authorization).to eq(order_id)
        expect(gateway).to have_received(:capture_authorization).
          with('AUTHORIZ123456789', money, request_id: 'spree-py_test123-capture')
      end

      it 'records the capture id on the payment through the capture workflow, keeping the authorization id' do
        order = create(:order, store: store, total: 10)
        payment = create(:payment, status: 'pending', order: order, payment_method: gateway, response_code: order_id,
                                   amount: 10, metadata: { 'paypal_authorization_id' => 'AUTHORIZ123456789' })
        allow_any_instance_of(described_class).to receive(:paypal_order).with(order_id).
          and_return(paypal_order_data(authorizations: [paypal_authorization]))
        allow_any_instance_of(described_class).to receive(:capture_authorization).and_return(paypal_capture)

        expect(Spree.payment_capture_workflow.call(payment: payment)).to be_success
        expect(payment.reload).to be_completed
        expect(payment.metadata).to eq(
          'paypal_authorization_id' => 'AUTHORIZ123456789', 'paypal_capture_id' => 'CAPTURE123456789A'
        )
      end

      it 'raises naming the pending reason when PayPal holds the capture' do
        allow(gateway).to receive(:capture_authorization).
          and_return(paypal_capture(status: 'PENDING', reason: 'PENDING_REVIEW'))

        expect { capture }.to raise_error(
          described_class::PaypalError,
          'PayPal is holding this capture: PENDING_REVIEW. It completes when PayPal releases it.'
        )
      end

      it "raises with PayPal's reason when the authorization has expired" do
        allow(gateway).to receive(:capture_authorization).
          and_raise(paypal_error('AUTHORIZATION_EXPIRED', 'The authorization has expired.'))

        expect { capture }.to raise_error(described_class::PaypalError, 'AUTHORIZATION_EXPIRED: The authorization has expired.') { |error|
          expect(error.issue).to eq('AUTHORIZATION_EXPIRED')
        }
      end

      it 'raises an ambiguous error when the capture gets no answer' do
        allow(gateway).to receive(:capture_authorization).and_raise(Faraday::TimeoutError, 'timed out')

        expect { capture }.to raise_error(Spree::Core::AmbiguousGatewayError)
      end

      it 'raises an ambiguous error for a server error the SDK cannot read' do
        response = PaypalHelpers::PaypalResponse.new(502, '<html>Bad Gateway</html>', {})
        allow(gateway).to receive(:capture_authorization).and_raise(PaypalServerSdk::APIException.new('Bad Gateway', response))

        expect { capture }.to raise_error(Spree::Core::AmbiguousGatewayError)
      end

      it 'raises an ambiguous error when PayPal answers the capture with a server error' do
        allow(gateway).to receive(:capture_authorization).and_raise(paypal_error('INTERNAL_SERVER_ERROR', status: 500))

        expect { capture }.to raise_error(Spree::Core::AmbiguousGatewayError, /could not say whether it took the payment/)
      end
    end

    it 'succeeds without a call when the order was captured already' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture]))
      allow(gateway).to receive(:capture_authorization)

      expect(capture).to be_success
      expect(capture.authorization).to eq(order_id)
      expect(gateway).not_to have_received(:capture_authorization)
    end

    it 'records the id of a capture PayPal already took' do
      order = create(:order, store: store, total: 10)
      payment = create(:payment, order: order, payment_method: gateway, response_code: order_id, amount: 10)
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture]))

      gateway.capture(money, order_id, gateway_options.merge(payment_prefixed_id: payment.prefixed_id))

      expect(payment.reload.metadata['paypal_capture_id']).to eq('CAPTURE123456789A')
    end

    it 'refuses to report an earlier capture of another amount as this one' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture(value: '4.00')]))

      expect { capture }.to raise_error(
        Spree::Core::GatewayError, 'PayPal already captured 4.00 USD on this order, not the 10.00 USD asked for.'
      )
    end

    it 'raises when an earlier capture is still pending' do
      allow(gateway).to receive(:paypal_order).
        and_return(paypal_order_data(captures: [paypal_capture(status: 'PENDING', reason: 'ECHECK')]))

      expect { capture }.to raise_error(described_class::PaypalError, /holding this capture: ECHECK/)
    end

    it 'raises naming the status of an authorization that can no longer be captured' do
      allow(gateway).to receive(:paypal_order).
        and_return(paypal_order_data(authorizations: [paypal_authorization(status: 'EXPIRED')]))

      expect { capture }.to raise_error(Spree::Core::GatewayError, /its authorization is EXPIRED/)
    end

    it 'reports a read that gets no answer as a plain gateway error' do
      allow(gateway).to receive(:paypal_order).and_raise(Faraday::TimeoutError, 'timed out')

      expect { capture }.to raise_error(Spree::Core::GatewayError) { |error|
        expect(error).not_to be_a(Spree::Core::AmbiguousGatewayError)
      }
    end

    it 'captures part of an authorization against PayPal',
       vcr: { cassette_name: 'capture_authorization' } do
      # Recording needs an order a sandbox buyer approved and the server
      # authorized; PAYPAL_AUTHORIZED_ORDER_ID names it.
      paypal_order_id = ENV.fetch('PAYPAL_AUTHORIZED_ORDER_ID', order_id)
      partial = Spree::Money.new(BigDecimal('5'), currency: 'USD')

      response = gateway.capture(partial, paypal_order_id, gateway_options)

      expect(response).to be_success
      expect(response.authorization).to eq(paypal_order_id)
      expect(response.params['status']).to eq('COMPLETED')
    end
  end

  describe '#credit' do
    let(:refund) { instance_double(Spree::Refund, prefixed_id: 're_test123') }

    it 'refunds the capture keyed on the refund and answers with the refund id' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture]))
      allow(gateway).to receive(:refund_capture).and_return({ 'id' => 'REFUND1234567890A', 'status' => 'COMPLETED' })

      response = gateway.credit(money, order_id, originator: refund)

      expect(response.authorization).to eq('REFUND1234567890A')
      expect(gateway).to have_received(:refund_capture).
        with('CAPTURE123456789A', money, request_id: 'spree-re_test123-refund')
    end

    it 'raises when the order has no capture' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(authorizations: [paypal_authorization]))

      expect { gateway.credit(money, order_id, originator: refund) }.
        to raise_error(Spree::Core::GatewayError, 'This PayPal order has no capture to refund.')
    end

    it 'raises when PayPal answers that it did not make the refund' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture]))
      allow(gateway).to receive(:refund_capture).and_return({ 'id' => 'REFUND1234567890A', 'status' => 'FAILED' })

      expect { gateway.credit(money, order_id, originator: refund) }.
        to raise_error(Spree::Core::GatewayError, 'PayPal did not complete the refund (status FAILED).')
    end

    it 'refunds a capture against PayPal', vcr: { cassette_name: 'refund_capture' } do
      # Recording needs a captured sandbox order; PAYPAL_CAPTURED_ORDER_ID names it.
      paypal_order_id = ENV.fetch('PAYPAL_CAPTURED_ORDER_ID', order_id)

      response = gateway.credit(Spree::Money.new(BigDecimal('1'), currency: 'USD'), paypal_order_id, originator: refund)

      expect(response).to be_success
      expect(response.params['status']).to eq('COMPLETED')
    end
  end

  describe '#void' do
    subject(:void) { gateway.void(order_id, gateway_options) }

    it 'voids the authorization, keyed on the payment, and answers with the order id' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(authorizations: [paypal_authorization]))
      allow(gateway).to receive(:void_authorization).and_return({ 'status' => 'VOIDED' })

      expect(void.authorization).to eq(order_id)
      expect(gateway).to have_received(:void_authorization).
        with('AUTHORIZ123456789', request_id: 'spree-py_test123-void')
    end

    it 'succeeds without a call for an uncaptured CAPTURE order' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(status: 'APPROVED'))
      allow(gateway).to receive(:void_authorization)

      expect(void).to be_success
      expect(gateway).not_to have_received(:void_authorization)
    end

    it 'raises while a capture is pending' do
      allow(gateway).to receive(:paypal_order).
        and_return(paypal_order_data(captures: [paypal_capture(status: 'PENDING', reason: 'ECHECK')]))

      expect { void }.to raise_error(
        described_class::PaypalError,
        'PayPal is still holding a capture on this payment; refund it once it completes.'
      )
    end

    it 'raises for a captured order' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(captures: [paypal_capture]))

      expect { void }.to raise_error(Spree::Core::GatewayError, /refund it instead/)
    end

    it 'voids an authorization against PayPal', vcr: { cassette_name: 'void_authorization' } do
      # Recording needs another authorized sandbox order; PAYPAL_VOIDABLE_ORDER_ID names it.
      paypal_order_id = ENV.fetch('PAYPAL_VOIDABLE_ORDER_ID', order_id)

      response = gateway.void(paypal_order_id, gateway_options)

      expect(response).to be_success
      expect(response.authorization).to eq(paypal_order_id)
    end
  end

  describe '#cancel' do
    let!(:refund_reason) { Spree::RefundReason.first || create(:default_refund_reason) }
    let(:order) { create(:order, store: store, total: 10) }

    context 'when the payment is completed' do
      let!(:payment) do
        create(:payment, status: 'completed', order: order, payment_method: gateway, amount: 10, response_code: order_id)
      end

      # The refund workflow credits through the payment's own copy of the gateway.
      before do
        allow_any_instance_of(described_class).to receive(:paypal_order).
          and_return(paypal_order_data(captures: [paypal_capture]))
        allow_any_instance_of(described_class).to receive(:refund_capture).
          and_return({ 'id' => 'REFUND1234567890A', 'status' => 'COMPLETED' })
      end

      it 'refunds what is left and keeps the order id as the authorization' do
        response = nil
        expect { response = gateway.cancel(order_id, payment) }.to change(Spree::Refund, :count).by(1)

        expect(payment.refunds.last.transaction_id).to eq('REFUND1234567890A')
        expect(response.authorization).to eq(order_id)
      end

      it 'leaves the money when the caller asked to keep it' do
        expect { gateway.cancel(order_id, payment, refund: false) }.not_to change(Spree::Refund, :count)
      end
    end

    context 'when the payment is not completed' do
      let!(:payment) { create(:payment, order: order, payment_method: gateway, amount: 10, response_code: order_id) }

      it 'voids the authorization' do
        allow(gateway).to receive(:paypal_order).and_return(paypal_order_data(authorizations: [paypal_authorization]))
        allow(gateway).to receive(:void_authorization).and_return({ 'status' => 'VOIDED' })

        expect(gateway.cancel(order_id, payment).authorization).to eq(order_id)
        expect(gateway).to have_received(:void_authorization).
          with('AUTHORIZ123456789', request_id: "spree-#{payment.prefixed_id}-void")
      end
    end
  end
end
