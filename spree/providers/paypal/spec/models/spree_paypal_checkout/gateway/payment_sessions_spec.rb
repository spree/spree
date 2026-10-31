require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway::PaymentSessions do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store, capture_method: 'checkout') }
  let(:cart) { create(:cart_ready_for_delivery, store: store, line_items_count: 1, line_items_price: BigDecimal('10')) }
  let(:paypal_order_id) { 'ORDER1234567890AB' }

  def session_for(cart, **attrs)
    create(:paypal_checkout_payment_session, owner: cart, payment_method: gateway, amount: cart.total, **attrs)
  end

  def approved_order(amount: format('%.2f', cart.total), currency: 'USD', **attrs)
    paypal_order_data(id: paypal_order_id, status: 'APPROVED', **attrs).tap do |order|
      order['purchase_units'].first['amount'] = { 'currency_code' => currency, 'value' => amount }
    end
  end

  def captured_order(status: 'COMPLETED', reason: nil, value: format('%.2f', cart.total), payment_source: nil)
    approved_order(
      status: 'COMPLETED',
      captures: [paypal_capture(status: status, reason: reason, value: value)],
      extra: payment_source ? { 'payment_source' => payment_source } : {}
    )
  end

  describe '#create_payment_session' do
    subject(:payment_session) { gateway.create_payment_session(order: cart, external_data: external_data) }

    let(:external_data) { {} }

    before do
      allow(gateway).to receive(:create_paypal_order).and_return({ 'id' => paypal_order_id, 'status' => 'CREATED' })
    end

    it 'creates the PayPal order and stores its id, the client id and the intent' do
      expect(payment_session).to be_persisted
      expect(payment_session.external_id).to eq(paypal_order_id)
      expect(payment_session.amount).to eq(cart.total)
      expect(payment_session.external_data).to eq('client_id' => 'paypal_client_id_test', 'intent' => 'CAPTURE')
    end

    it 'sends the order the presenter builds' do
      payment_session

      expect(gateway).to have_received(:create_paypal_order) do |order_request|
        expect(order_request.to_hash['intent']).to eq('CAPTURE')
        expect(order_request.to_hash['purchase_units'].first['custom_id']).to eq(cart.prefixed_id)
      end
    end

    context 'with a method that captures on dispatch' do
      let(:gateway) { create(:paypal_checkout_gateway, store: store, capture_method: 'on_dispatch') }

      it 'asks for an authorization' do
        expect(payment_session.intent).to eq('AUTHORIZE')
      end
    end

    context 'when the client sends values for keys the gem owns' do
      let(:external_data) { { 'client_id' => 'forged', 'intent' => 'AUTHORIZE', 'attempt' => 7, 'note' => 'kept' } }

      it 'ignores them and keeps the rest' do
        expect(payment_session.external_data).to eq(
          'client_id' => 'paypal_client_id_test', 'intent' => 'CAPTURE', 'note' => 'kept'
        )
      end
    end

    it 'refuses a zero amount' do
      expect { gateway.create_payment_session(order: cart, amount: '0') }.
        to raise_error(Spree::Core::GatewayError, 'Payment session amount must be greater than zero')
    end

    it 'refuses a cart that already has a completed PayPal session' do
      session_for(cart, status: 'completed')

      expect { payment_session }.to raise_error(Spree::Core::GatewayError, /already in progress/)
      expect(gateway).not_to have_received(:create_paypal_order)
    end

    it 'cancels the open sessions it replaces' do
      earlier = session_for(cart, external_id: 'EARLIERORDER12345')

      payment_session

      expect(earlier.reload).to be_canceled
    end

    it 'turns PayPal being unreachable while replacing a session into a gateway error' do
      session_for(cart, external_id: 'EARLIERORDER12345', external_data: { 'attempt' => 1 })
      allow(gateway).to receive(:paypal_order).and_raise(Faraday::ConnectionFailed, 'refused')

      expect { payment_session }.to raise_error(Spree::Core::GatewayError, 'refused')
    end

    it 'creates an order with the CAPTURE intent and a fixed shipping address', vcr: { cassette_name: 'create_order_capture' } do
      allow(gateway).to receive(:create_paypal_order).and_call_original

      expect(payment_session.external_id).to be_present
    end

    context 'with a digital cart and an authorizing method' do
      let(:gateway) { create(:paypal_checkout_gateway, store: store, capture_method: 'on_dispatch') }
      let(:cart) { create(:cart_with_line_items, store: store, line_items_price: BigDecimal('10')) }

      it 'creates an order with the AUTHORIZE intent and no shipping', vcr: { cassette_name: 'create_order_authorize' } do
        allow(gateway).to receive(:create_paypal_order).and_call_original
        allow(cart).to receive(:shipping_address_required?).and_return(false)

        expect(payment_session.external_id).to be_present
        expect(payment_session.intent).to eq('AUTHORIZE')
      end
    end
  end

  describe '#update_payment_session' do
    let(:payment_session) { session_for(cart, external_id: paypal_order_id) }

    before { allow(gateway).to receive(:patch_paypal_order) }

    it 'replaces the purchase unit at PayPal before taking the new amount' do
      gateway.update_payment_session(payment_session: payment_session, amount: '25.00')

      expect(gateway).to have_received(:patch_paypal_order) do |order_id, purchase_unit|
        expect(order_id).to eq(paypal_order_id)
        expect(purchase_unit.to_hash['amount']['value']).to eq('25.00')
      end
      expect(payment_session.reload.amount).to eq(BigDecimal('25'))
    end

    it 'keeps the old amount when PayPal refuses the patch' do
      allow(gateway).to receive(:patch_paypal_order).and_raise(paypal_error('ORDER_ALREADY_CAPTURED'))

      expect { gateway.update_payment_session(payment_session: payment_session, amount: '25.00') }.
        to raise_error(Spree::Core::GatewayError, /ORDER_ALREADY_CAPTURED/)
      expect(payment_session.reload.amount).to eq(cart.total)
    end

    it 'leaves PayPal alone when the amount did not change' do
      gateway.update_payment_session(payment_session: payment_session, amount: cart.total.to_s)

      expect(gateway).not_to have_received(:patch_paypal_order)
    end

    it 'ignores values for keys the gem owns' do
      gateway.update_payment_session(payment_session: payment_session, external_data: { 'intent' => 'AUTHORIZE', 'note' => 'x' })

      expect(payment_session.reload.external_data).to include('intent' => 'CAPTURE', 'note' => 'x')
    end

    it 'patches the amount against PayPal', vcr: { cassette_name: 'update_order_amount' } do
      allow(gateway).to receive(:patch_paypal_order).and_call_original
      # Recording needs an order this method created; PAYPAL_CREATED_ORDER_ID names it.
      payment_session.update_columns(external_id: ENV.fetch('PAYPAL_CREATED_ORDER_ID', paypal_order_id))

      gateway.update_payment_session(payment_session: payment_session, amount: (cart.total + 1).to_s)

      expect(payment_session.reload.amount).to eq(cart.total + 1)
    end
  end

  describe '#complete_payment_session' do
    subject(:complete) { gateway.complete_payment_session(payment_session: payment_session) }

    let(:payment_session) { session_for(cart, external_id: paypal_order_id) }
    let(:wallet) do
      { 'paypal' => { 'email_address' => 'buyer@example.com', 'account_id' => 'PAYERID1234', 'account_status' => 'VERIFIED',
                      'name' => { 'given_name' => 'Ada', 'surname' => 'Lovelace' } } }
    end

    before { allow(gateway).to receive(:paypal_order).with(paypal_order_id).and_return(approved_order) }

    it 'captures with a request id for this attempt and settles a captured payment' do
      allow(gateway).to receive(:capture_paypal_order).and_return(captured_order(payment_source: wallet))

      complete

      expect(gateway).to have_received(:capture_paypal_order).
        with(paypal_order_id, request_id: "#{payment_session.prefixed_id}-capture-1")
      expect(payment_session.reload).to be_completed
      payment = payment_session.payment
      expect(payment).to be_completed
      expect(payment.response_code).to eq(paypal_order_id)
      expect(payment.metadata['paypal_capture_id']).to eq('CAPTURE123456789A')
      expect(payment.source).to be_a(SpreePaypalCheckout::PaymentSources::Paypal)
      expect(payment.source.email).to eq('buyer@example.com')
      expect(payment_session.external_data).to include(
        'client_id' => 'paypal_client_id_test', 'intent' => 'CAPTURE',
        'paypal_result' => include('capture_id' => 'CAPTURE123456789A', 'capture_status' => 'COMPLETED')
      )
    end

    it 'never completes the cart' do
      allow(gateway).to receive(:capture_paypal_order).and_return(captured_order)

      expect { complete }.not_to(change { Spree::Order.count })
    end

    it 'settles a capture PayPal holds as pending without taking it' do
      allow(gateway).to receive(:capture_paypal_order).and_return(captured_order(status: 'PENDING', reason: 'ECHECK'))

      complete

      expect(payment_session.reload).to be_completed
      expect(payment_session.payment).to be_present
      expect(payment_session.payment).not_to be_completed
    end

    context 'with an authorizing session' do
      let(:payment_session) do
        session_for(cart, external_id: paypal_order_id, external_data: { 'client_id' => 'x', 'intent' => 'AUTHORIZE' })
      end

      it 'authorizes and settles a pending payment' do
        allow(gateway).to receive(:authorize_paypal_order).
          and_return(approved_order(status: 'COMPLETED', authorizations: [paypal_authorization(value: format('%.2f', cart.total))]))

        complete

        expect(gateway).to have_received(:authorize_paypal_order).
          with(paypal_order_id, request_id: "#{payment_session.prefixed_id}-authorize-1")
        payment = payment_session.reload.payment
        expect(payment).to be_pending
        expect(payment.metadata['paypal_authorization_id']).to eq('AUTHORIZ123456789')
      end
    end

    it 'fails the session without moving money when the order amount differs' do
      allow(gateway).to receive(:paypal_order).and_return(approved_order(amount: '1.00'))
      allow(gateway).to receive(:capture_paypal_order)

      complete

      expect(payment_session.reload).to be_failed
      expect(gateway).not_to have_received(:capture_paypal_order)
    end

    it 'fails the session without moving money when the currency differs' do
      allow(gateway).to receive(:paypal_order).and_return(approved_order(currency: 'EUR'))
      allow(gateway).to receive(:capture_paypal_order)

      complete

      expect(payment_session.reload).to be_failed
      expect(gateway).not_to have_received(:capture_paypal_order)
    end

    it 'settles and reports a captured amount that still differs' do
      allow(gateway).to receive(:capture_paypal_order).and_return(captured_order(value: '9.99'))
      allow(Rails.error).to receive(:report)

      complete

      expect(payment_session.reload).to be_completed
      expect(Rails.error).to have_received(:report).with(
        an_instance_of(Spree::Core::GatewayError), hash_including(source: 'spree_paypal_checkout.complete_payment_session')
      )
    end

    it 'settles an order a timed-out capture already took, without capturing again' do
      allow(gateway).to receive(:paypal_order).and_return(captured_order)
      allow(gateway).to receive(:capture_paypal_order)

      complete

      expect(payment_session.reload).to be_completed
      expect(gateway).not_to have_received(:capture_paypal_order)
    end

    context 'when PayPal declines the funding source' do
      before { allow(gateway).to receive(:capture_paypal_order).and_raise(paypal_error('INSTRUMENT_DECLINED')) }

      it 'leaves the session open for another try and moves the attempt on' do
        expect { complete }.to raise_error(Spree::Core::GatewayError, /INSTRUMENT_DECLINED/)

        expect(payment_session.reload).to be_pending
        expect(payment_session.attempt).to eq(2)
      end

      it 'sends the next try as a new request' do
        expect { complete }.to raise_error(Spree::Core::GatewayError)
        allow(gateway).to receive(:capture_paypal_order).and_return(captured_order)

        gateway.complete_payment_session(payment_session: payment_session.reload)

        expect(gateway).to have_received(:capture_paypal_order).
          with(paypal_order_id, request_id: "#{payment_session.prefixed_id}-capture-2")
      end
    end

    it 'fails the session on any other decline' do
      allow(gateway).to receive(:capture_paypal_order).and_raise(paypal_error('ORDER_NOT_APPROVED'))

      expect { complete }.to raise_error(Spree::Core::GatewayError, /ORDER_NOT_APPROVED/)
      expect(payment_session.reload).to be_failed
    end

    it 'fails the session when the capture comes back declined' do
      allow(gateway).to receive(:capture_paypal_order).and_return(captured_order(status: 'DECLINED'))

      expect { complete }.to raise_error(Spree::Core::GatewayError, 'PayPal declined the payment (status DECLINED).')
      expect(payment_session.reload).to be_failed
    end

    it 'leaves the session open and reports an ambiguous error when the capture gets no answer' do
      allow(gateway).to receive(:capture_paypal_order).and_raise(Faraday::TimeoutError, 'timed out')

      expect { complete }.to raise_error(Spree::Core::AmbiguousGatewayError)
      expect(payment_session.reload).to be_pending
      expect(payment_session.attempt).to eq(1)
      expect(payment_session).to be_complete_attempted
    end

    it 'leaves the session open and reports an ambiguous error when PayPal answers with a server error' do
      allow(gateway).to receive(:capture_paypal_order).and_raise(paypal_error('INTERNAL_SERVER_ERROR', status: 503))

      expect { complete }.to raise_error(Spree::Core::AmbiguousGatewayError)
      expect(payment_session.reload).to be_pending
      expect(payment_session.attempt).to eq(1)
    end

    it 'leaves the session open when PayPal turns the request away before looking at it' do
      allow(gateway).to receive(:capture_paypal_order).and_raise(paypal_error('RATE_LIMIT_REACHED', status: 429))

      expect { complete }.to raise_error(Spree::Core::GatewayError, /RATE_LIMIT_REACHED/)
      expect(payment_session.reload).to be_pending
    end

    it 'refuses a session that is not open' do
      payment_session.update_columns(status: 'failed')
      allow(gateway).to receive(:capture_paypal_order)

      expect { complete }.to raise_error(Spree::Core::GatewayError, /can no longer be completed/)
      expect(gateway).not_to have_received(:capture_paypal_order)
    end

    context 'against PayPal' do
      # Recording needs a 10.00 USD order a sandbox buyer approved by hand.
      let(:cart) { create(:cart_with_line_items, store: store, line_items_price: BigDecimal('10')) }

      before do
        allow(gateway).to receive(:paypal_order).and_call_original
        payment_session.update_columns(amount: BigDecimal('10'), external_id: recorded_order_id)
      end

      context 'when capturing', vcr: { cassette_name: 'complete_capture' } do
        let(:recorded_order_id) { ENV.fetch('PAYPAL_APPROVED_CAPTURE_ORDER_ID', paypal_order_id) }

        it 'captures the approved order' do
          gateway.complete_payment_session(payment_session: payment_session.reload)

          expect(payment_session.reload).to be_completed
          expect(payment_session.payment).to be_completed
        end
      end

      context 'when authorizing', vcr: { cassette_name: 'complete_authorize' } do
        let(:recorded_order_id) { ENV.fetch('PAYPAL_APPROVED_AUTHORIZE_ORDER_ID', paypal_order_id) }

        it 'authorizes the approved order' do
          payment_session.update_columns(external_data: { 'client_id' => 'x', 'intent' => 'AUTHORIZE' })

          gateway.complete_payment_session(payment_session: payment_session.reload)

          expect(payment_session.reload.payment).to be_pending
        end
      end

      context 'when the funding source is declined', vcr: { cassette_name: 'complete_instrument_declined' } do
        let(:recorded_order_id) { ENV.fetch('PAYPAL_APPROVED_DECLINED_ORDER_ID', paypal_order_id) }

        it 'keeps the session open' do
          # PayPal's sandbox negative testing forces the decline while recording.
          allow(gateway.client.orders).to receive(:capture_order).and_wrap_original do |original, options|
            original.call(options.merge('paypal_mock_response' => '{"mock_application_codes":"INSTRUMENT_DECLINED"}'))
          end

          expect { gateway.complete_payment_session(payment_session: payment_session.reload) }.
            to raise_error(Spree::Core::GatewayError, /INSTRUMENT_DECLINED/)
          expect(payment_session.reload).to be_pending
        end
      end
    end
  end

  describe '#cancel_payment_session' do
    subject(:cancel) { gateway.cancel_payment_session(payment_session: payment_session) }

    let(:payment_session) { session_for(cart, external_id: paypal_order_id, external_data: external_data) }
    let(:external_data) { { 'client_id' => 'x', 'intent' => 'CAPTURE', 'attempt' => 1 } }

    context 'when Complete was never reached' do
      let(:external_data) { { 'client_id' => 'x', 'intent' => 'CAPTURE' } }

      it 'cancels without asking PayPal' do
        allow(gateway).to receive(:paypal_order)

        expect(cancel).to be(true)
        expect(payment_session.reload).to be_canceled
        expect(gateway).not_to have_received(:paypal_order)
      end
    end

    it 'cancels when nothing moved' do
      allow(gateway).to receive(:paypal_order).and_return(approved_order)

      expect(cancel).to be(true)
    end

    it 'voids an authorization and cancels' do
      allow(gateway).to receive(:paypal_order).and_return(approved_order(authorizations: [paypal_authorization]))
      allow(gateway).to receive(:void_authorization).and_return({})

      expect(cancel).to be(true)
      expect(gateway).to have_received(:void_authorization).
        with('AUTHORIZ123456789', request_id: "#{payment_session.prefixed_id}-void")
    end

    it 'refuses a captured order' do
      allow(gateway).to receive(:paypal_order).and_return(captured_order)

      expect { cancel }.to raise_error(Spree::Core::GatewayError, /already taken the money/)
      expect(payment_session.reload).not_to be_canceled
    end

    it "treats PayPal's refusal as a gateway error" do
      allow(gateway).to receive(:paypal_order).and_raise(paypal_error('PERMISSION_DENIED', status: 403))

      expect { cancel }.to raise_error(Spree::Core::GatewayError, /PERMISSION_DENIED/)
    end

    it 'cancels an order the account no longer knows' do
      allow(gateway).to receive(:paypal_order).and_raise(paypal_error('RESOURCE_NOT_FOUND', status: 404))

      expect(cancel).to be(true)
    end

    [
      ['a timeout', -> { Faraday::TimeoutError.new('timed out') }, Faraday::TimeoutError],
      ['a rate limit', -> { paypal_error('RATE_LIMIT_REACHED', status: 429) }, PaypalServerSdk::ErrorException],
      ['a server error', -> { paypal_error('INTERNAL_SERVER_ERROR', status: 500) }, PaypalServerSdk::ErrorException],
      ['rejected credentials', -> { CoreLibrary::AuthValidationException.new('invalid') }, CoreLibrary::AuthValidationException]
    ].each do |label, error, error_class|
      it "raises PayPal's own error for #{label}, so the unused-session job retries" do
        allow(gateway).to receive(:paypal_order).and_raise(instance_exec(&error))

        expect { cancel }.to raise_error(error_class) { |raised| expect(raised).not_to be_a(Spree::Core::GatewayError) }
        expect(payment_session.reload).not_to be_canceled
      end
    end
  end
end
