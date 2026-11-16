require 'spec_helper'

RSpec.describe SpreeAdyen::Gateway, 'payment sessions' do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, :configured, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:return_url) { 'https://shop.example.com/checkout/return' }
  let(:sessions_url) { "#{AdyenHelpers::CHECKOUT_URL}/sessions" }

  before do
    create(:allowed_origin, store: store, origin: 'https://shop.example.com')
    allow_any_instance_of(described_class).to receive(:wait_before_retry)
  end

  def stub_session_create(id: 'CSAAAA1111BBBB22', session_data: 'Ab02b4c0!CREATED')
    stub_request(:post, sessions_url).
      to_return(adyen_json({ 'id' => id, 'sessionData' => session_data, 'expiresAt' => 1.hour.from_now.iso8601 }, status: 201))
  end

  def create_session(external_data = { 'return_url' => return_url })
    gateway.create_payment_session(order: order, external_data: external_data)
  end

  describe '#create_payment_session' do
    it 'creates an unpayable session and stores what the storefront and the gem need' do
      stub = stub_session_create
      session = create_session('return_url' => return_url, 'channel' => 'iOS', 'session_data' => 'forged', 'payable' => true)

      expect(stub.with(body: hash_including('payable' => false, 'returnUrl' => return_url, 'channel' => 'iOS'))).to have_been_requested
      expect(session).to have_attributes(external_id: 'CSAAAA1111BBBB22', status: 'pending', amount: order.total_minus_store_credits)
      expect(session.external_data).to include(
        'session_data' => 'Ab02b4c0!CREATED', 'client_key' => 'test_CLIENTKEY', 'environment' => 'test', 'channel' => 'iOS',
        'return_url' => return_url, 'reference' => "#{order.prefixed_id}-1", 'payable' => false
      )
    end

    it 'keys the request on the cart, its session count and what it asks for' do
      stub_session_create
      create_session
      key = ->(request) { request.headers['Idempotency-Key'] }
      first_key = nil
      expect(a_request(:post, sessions_url).with { |request| first_key = key.call(request) }).to have_been_made
      expect(first_key).to match(/\Aspree-#{order.prefixed_id}-1-session-\h{12}\z/)
      expect(first_key.length).to be < 64
    end

    it 'gets a new key for a corrected request after Adyen refused one' do
      keys = []
      stub_request(:post, sessions_url).
        with { |request| keys << request.headers['Idempotency-Key'] }.
        to_return(adyen_json({ 'errorCode' => '702', 'message' => 'Invalid field' }, status: 422)).then.
        to_return(adyen_json({ 'id' => 'CSRETRY000000001', 'sessionData' => 'x' }, status: 201))

      expect { create_session }.to raise_error(Spree::Core::GatewayError)
      create_session('return_url' => return_url, 'channel' => 'Android')

      expect(keys.uniq.size).to eq(2)
    end

    it 'refuses a zero amount' do
      expect { gateway.create_payment_session(order: order, amount: 0, external_data: { 'return_url' => return_url }) }.
        to raise_error(Spree::Core::GatewayError, /greater than zero/)
    end

    it 'refuses a return URL missing or outside the allowed origins' do
      expect { create_session({}) }.to raise_error(Spree::Core::GatewayError, /allowed origins/)
      expect { create_session('return_url' => 'https://evil.example.com/steal') }.to raise_error(Spree::Core::GatewayError, /allowed origins/)
    end

    it 'cancels the open sessions of the cart locally' do
      stub_session_create(id: 'CSFIRST000000001')
      first = create_session
      stub_session_create(id: 'CSSECOND00000002')

      create_session

      expect(first.reload).to be_canceled
      expect(a_request(:patch, %r{/sessions/})).not_to have_been_made
    end

    it 'refuses a cart with a completed Adyen session' do
      stub_session_create
      create_session.update_column(:status, 'completed')

      expect { create_session }.to raise_error(Spree::Core::GatewayError, /already been paid/)
    end
  end

  describe '#update_payment_session' do
    let(:session) { create(:adyen_payment_session, owner: order, payment_method: gateway) }

    it "changes Spree's amount only while the session is not payable, merging other data" do
      gateway.update_payment_session(payment_session: session, amount: '1.00', external_data: { 'note' => 'x', 'payable' => true })

      expect(session.reload.amount).to eq(1)
      expect(session.external_data).to include('note' => 'x', 'payable' => false)
      expect(a_request(:any, /adyen/)).not_to have_been_made
    end

    it 'refuses a new amount once the session is payable' do
      session.update!(external_data: session.external_data.merge('payable' => true))

      expect { gateway.update_payment_session(payment_session: session, amount: '1.00') }.
        to raise_error(Spree::Core::GatewayError, /Create a new payment session/)
    end

    describe 'submit' do
      let(:update_url) { "#{AdyenHelpers::CHECKOUT_URL}/sessions/#{session.external_id}" }

      it 'makes the session payable at the amount Spree holds' do
        minor_units = SpreeAdyen::Amounts.to_adyen(session.amount, session.currency)
        stub = stub_request(:patch, update_url).
               with(body: hash_including('sessionData' => 'Ab02b4c0!SESSIONDATA', 'payable' => true,
                                         'amount' => { 'value' => minor_units, 'currency' => session.currency })).
               to_return(adyen_json({ 'id' => session.external_id, 'sessionData' => 'Ab02b4c0!PAYABLE' }))

        gateway.update_payment_session(payment_session: session, amount: '999.00', external_data: { 'submit' => true })

        expect(stub).to have_been_requested
        expect(session.reload).to be_payable
        expect(session.session_data).to eq('Ab02b4c0!PAYABLE')
        expect(session.amount).not_to eq(999)
      end

      it 'answers a payable session from what is stored' do
        session.update!(external_data: session.external_data.merge('payable' => true))

        expect(gateway.update_payment_session(payment_session: session, external_data: { 'submit' => true })).to eq(session)
        expect(a_request(:patch, update_url)).not_to have_been_made
      end

      it 'refuses a session that is not pending' do
        session.cancel

        expect { gateway.update_payment_session(payment_session: session, external_data: { 'submit' => true }) }.
          to raise_error(Spree::Core::GatewayError, /can no longer be paid/)
      end

      it "raises Adyen's refusal of a repeated update" do
        stub_request(:patch, update_url).to_return(adyen_json({ 'errorCode' => '14_030', 'message' => 'Session is already payable' }, status: 422))

        expect { gateway.update_payment_session(payment_session: session, external_data: { 'submit' => true }) }.
          to raise_error(Spree::Core::GatewayError, /already payable/)
      end
    end
  end

  describe '#complete_payment_session' do
    let(:session) do
      create(:adyen_payment_session, owner: order, payment_method: gateway, amount: order.total,
                                     external_data: { 'session_data' => 'x', 'reference' => "#{order.prefixed_id}-1",
                                                      'manual_capture' => false, 'payable' => true })
    end
    let(:minor_units) { SpreeAdyen::Amounts.to_adyen(order.total, order.currency) }
    let(:result_url) { "#{AdyenHelpers::CHECKOUT_URL}/sessions/#{session.external_id}?sessionResult=RESULT" }
    let(:details_url) { "#{AdyenHelpers::CHECKOUT_URL}/payments/details" }

    def session_result(status:, result_code: 'Authorised', payments: 1, value: minor_units, variant: { 'type' => 'scheme', 'brand' => 'visa' })
      {
        'id' => session.external_id, 'status' => status, 'reference' => "#{order.prefixed_id}-1",
        'payments' => Array.new(payments) do |index|
          { 'pspReference' => "PSP000000000000#{index}", 'resultCode' => result_code, 'paymentMethod' => variant,
            'amount' => { 'value' => value, 'currency' => order.currency },
            'additionalData' => { 'cardSummary' => '1111', 'expiryDate' => '03/2030' } }
        end
      }
    end

    def complete(params = { 'session_result' => 'RESULT' })
      gateway.complete_payment_session(payment_session: session, params: params)
    end

    it 'settles a completed session as captured and completes it' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed')))

      complete

      payment = session.reload.payment
      expect(session).to be_completed
      expect(payment).to be_completed
      expect(payment.metadata).to include('adyen_psp_reference' => 'PSP0000000000000', 'adyen_variant' => 'visa')
      expect(payment.capture_events.sole.transaction_id).to eq('PSP0000000000000')
      expect(payment.source).to be_a(SpreeAdyen::PaymentSources::Card)
    end

    it 'settles as authorized when the session asked Adyen to hold the money' do
      session.update!(external_data: session.external_data.merge('manual_capture' => true))
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed')))

      complete

      expect(session.reload.payment).to be_pending
    end

    it 'settles as captured a method Adyen captures at once, whatever the session asked' do
      session.update!(external_data: session.external_data.merge('manual_capture' => true))
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed', variant: { 'type' => 'ideal' })))

      complete

      expect(session.reload.payment).to be_completed
      expect(session.payment.source).to be_a(SpreeAdyen::PaymentSources::Ideal)
    end

    it 'settles a pending payment as authorized' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'paymentPending', result_code: 'Received')))

      complete

      expect(session.reload.payment).to be_pending
    end

    it 'fails a session Adyen refused' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'refused', result_code: 'Refused')))

      complete

      expect(session.reload).to be_failed
      expect(session.payment).to be_nil
    end

    it 'expires an expired session' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'expired', payments: 0)))

      complete

      expect(session.reload.status).to eq('expired')
    end

    it "raises Adyen's reason for a session still active, leaving it open" do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'active', payments: 0)))

      expect { complete }.to raise_error(Spree::Core::GatewayError, /Adyen did not accept the payment/)
      expect(session.reload).to be_pending
    end

    it 'settles nothing for a payment of the wrong amount' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed', value: minor_units + 1)))

      expect { complete }.to raise_error(Spree::Core::GatewayError, /was not recorded/)
      expect(session.reload.payment).to be_nil
    end

    it 'settles nothing for two payments' do
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed', payments: 2)))

      expect { complete }.to raise_error(Spree::Core::GatewayError, /2 payments/)
      expect(session.reload.payment).to be_nil
    end

    it 'settles a redirect that names this session' do
      stub_request(:post, details_url).with(body: hash_including('details' => { 'redirectResult' => 'REDIRECT' })).
        to_return(adyen_json({ 'pspReference' => 'PSPREDIRECT00001', 'resultCode' => 'Authorised', 'merchantReference' => "#{order.prefixed_id}-1",
                               'amount' => { 'value' => minor_units, 'currency' => order.currency }, 'paymentMethod' => { 'type' => 'ideal' } }))

      complete('external_data' => { 'redirect_result' => 'REDIRECT' })

      expect(session.reload).to be_completed
    end

    it 'settles nothing for a redirect of another session' do
      stub_request(:post, details_url).
        to_return(adyen_json({ 'pspReference' => 'PSPREDIRECT00002', 'resultCode' => 'Authorised', 'merchantReference' => 'cart_other-1',
                               'amount' => { 'value' => minor_units, 'currency' => order.currency }, 'paymentMethod' => { 'type' => 'ideal' } }))

      expect { complete('external_data' => { 'redirect_result' => 'REDIRECT' }) }.to raise_error(Spree::Core::GatewayError, /another session/)
      expect(session.reload.payment).to be_nil
    end

    it 'settles a session Spree canceled after it was made payable, which stays canceled' do
      session.cancel
      stub_request(:get, result_url).to_return(adyen_json(session_result(status: 'completed')))

      complete

      expect(session.reload).to be_canceled
      expect(session.payment).to be_completed
    end

    it 'requires a session or redirect result' do
      expect { complete({}) }.to raise_error(Spree::Core::GatewayError, /required/)
    end

    describe 'the source a payment gets' do
      it 'saves a card the buyer asked to keep' do
        result = session_result(status: 'completed')
        result['payments'][0]['additionalData']['tokenization.storedPaymentMethodId'] = 'STORED00000001'
        stub_request(:get, result_url).to_return(adyen_json(result))

        complete

        card = session.reload.payment.source
        expect(card).to be_a(Spree::CreditCard)
        expect(card).to have_attributes(gateway_payment_profile_id: 'STORED00000001', gateway_customer_profile_id: "customer_#{order.customer.id}",
                                        cc_type: 'visa', last_digits: '1111', customer: order.customer)
      end

      it 'records a wallet on the saved card' do
        result = session_result(status: 'completed', variant: { 'type' => 'applepay', 'brand' => 'mc' })
        result['payments'][0]['additionalData']['tokenization.storedPaymentMethodId'] = 'STORED00000002'
        stub_request(:get, result_url).to_return(adyen_json(result))

        complete

        expect(session.reload.payment.source).to have_attributes(cc_type: 'master', wallet: { 'type' => 'apple_pay' })
      end
    end
  end

  describe '#cancel_payment_session' do
    it 'cancels locally, with no Adyen call' do
      session = create(:adyen_payment_session, owner: order, payment_method: gateway)

      expect(gateway.cancel_payment_session(payment_session: session)).to be(true)
      expect(session.reload).to be_canceled
      expect(a_request(:any, /adyen/)).not_to have_been_made
    end
  end

  # Recorded against the test account by the author (Phase 15).
  describe 'against Adyen', :vcr do
    let(:customer) { create(:customer) }
    let(:order) { create(:order_with_line_items, store: store, customer: customer) }

    it 'creates a session for a signed-in customer', vcr: { cassette_name: 'session_create' } do
      expect(create_session.external_data['session_data']).to be_present
    end

    it 'creates a manual-capture session', vcr: { cassette_name: 'session_create_manual_capture' } do
      allow(gateway).to receive(:capture_at_checkout?).and_return(false)

      expect(create_session.manual_capture?).to be(true)
    end

    it 'creates an iOS session', vcr: { cassette_name: 'session_create_ios' } do
      expect(create_session('return_url' => return_url, 'channel' => 'iOS').external_data['channel']).to eq('iOS')
    end

    it "creates a guest's session", vcr: { cassette_name: 'session_create_guest' } do
      order.update_columns(customer_id: nil)

      expect(gateway.create_payment_session(order: order.reload, external_data: { 'return_url' => return_url })).to be_persisted
    end

    it 'makes a session payable', vcr: { cassette_name: 'session_submit' } do
      session = create_session

      gateway.update_payment_session(payment_session: session, external_data: { 'submit' => true })

      expect(session.reload).to be_payable
    end

    it 'has a repeated submit refused', vcr: { cassette_name: 'session_submit_already_payable' } do
      session = create(:adyen_payment_session, owner: order, payment_method: gateway,
                                               external_id: ENV.fetch('ADYEN_PAYABLE_SESSION_ID', 'CSPAYABLE0000001'),
                                               external_data: { 'session_data' => ENV.fetch('ADYEN_PAYABLE_SESSION_DATA', 'Ab02b4c0!PAYABLE') })

      expect { gateway.update_payment_session(payment_session: session, external_data: { 'submit' => true }) }.
        to raise_error(Spree::Core::GatewayError)
    end

    {
      'session_result_completed' => %w[PAID completed],
      'session_result_saved_card' => %w[SAVED_CARD completed],
      'session_result_payment_pending' => %w[PENDING processing],
      'session_result_refused' => %w[REFUSED failed],
      'session_result_expired' => %w[EXPIRED expired]
    }.each do |cassette, (env, status)|
      it "reads #{cassette.delete_prefix('session_result_')}", vcr: { cassette_name: cassette } do
        session = create(:adyen_payment_session, owner: order, payment_method: gateway,
                                                 external_id: ENV.fetch("ADYEN_#{env}_SESSION_ID", "CS#{env}0000001"),
                                                 amount: BigDecimal(ENV.fetch('ADYEN_SESSION_AMOUNT', order.total.to_s)),
                                                 external_data: { 'reference' => "#{order.prefixed_id}-1", 'payable' => true })

        gateway.complete_payment_session(payment_session: session, params: { 'session_result' => ENV.fetch("ADYEN_#{env}_SESSION_RESULT", 'RESULT') })

        expect(session.reload.status).to eq(status == 'processing' ? 'completed' : status)
      end
    end

    it 'reads an active session', vcr: { cassette_name: 'session_result_active' } do
      session = create(:adyen_payment_session, owner: order, payment_method: gateway,
                                               external_id: ENV.fetch('ADYEN_ACTIVE_SESSION_ID', 'CSACTIVE00000001'))

      expect {
        gateway.complete_payment_session(payment_session: session, params: { 'session_result' => ENV.fetch('ADYEN_ACTIVE_SESSION_RESULT', 'RESULT') })
      }.
        to raise_error(Spree::Core::GatewayError)
    end

    it 'reads an authorised redirect', vcr: { cassette_name: 'payment_details_authorised' } do
      session = create(:adyen_payment_session, owner: order, payment_method: gateway,
                                               amount: BigDecimal(ENV.fetch('ADYEN_SESSION_AMOUNT', order.total.to_s)),
                                               external_data: { 'reference' => ENV.fetch('ADYEN_REDIRECT_REFERENCE', "#{order.prefixed_id}-1") })

      gateway.complete_payment_session(payment_session: session,
                                       params: { 'external_data' => { 'redirect_result' => ENV.fetch('ADYEN_AUTHORISED_REDIRECT_RESULT',
                                                                                                     'REDIRECT') } })

      expect(session.reload).to be_completed
    end

    it 'reads a refused redirect', vcr: { cassette_name: 'payment_details_refused' } do
      session = create(:adyen_payment_session, owner: order, payment_method: gateway)

      expect do
        gateway.complete_payment_session(payment_session: session,
                                         params: { 'external_data' => { 'redirect_result' => ENV.fetch('ADYEN_REFUSED_REDIRECT_RESULT',
                                                                                                       'REDIRECT') } })
      end.to raise_error(Spree::Core::GatewayError, /Adyen did not accept the payment/)
    end
  end
end
