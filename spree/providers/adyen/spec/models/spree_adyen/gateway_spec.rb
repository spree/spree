require 'spec_helper'

RSpec.describe SpreeAdyen::Gateway do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }

  describe 'declarations' do
    it 'is registered as a payment method' do
      expect(Rails.application.config.spree.payment_methods).to include(described_class)
    end

    it 'answers adyen as its api type' do
      expect(described_class.api_type).to eq('adyen')
    end

    it 'asks the operator for four fields and hides the ones configuration writes' do
      keys = described_class.serialized_preference_schema.pluck(:key)

      expect(keys).to contain_exactly(:api_key, :merchant_account, :test_mode, :live_url_prefix)
      %i[client_key hmac_key previous_hmac_key webhook_id].each do |key|
        expect(gateway.preference_internal(key)).to be(true)
      end
    end

    it 'keeps the keys secret' do
      %i[api_key client_key hmac_key previous_hmac_key].each do |key|
        expect(gateway.preference_type(key)).to eq(:password)
      end
    end

    it 'starts in test mode' do
      expect(described_class.new.preferred_test_mode).to be(true)
    end

    it 'requires a live URL prefix only outside test mode' do
      expect(gateway).to be_valid

      gateway.preferred_test_mode = false
      expect(gateway).not_to be_valid
      expect(gateway.errors[:preferred_live_url_prefix]).to be_present

      gateway.preferred_live_url_prefix = '1797a841fbb37ca7-AdyenDemo'
      expect(gateway).to be_valid
    end

    it 'takes money amounts, a payment session and saved cards' do
      expect(described_class.accepts_money_amounts).to be(true)
      expect(gateway.session_required?).to be(true)
      expect(gateway.payment_profiles_supported?).to be(true)
    end

    it 'names its gallery logo and guide' do
      expect(described_class.logo_url).to end_with('adyen.png')
      expect(described_class.docs_url).to end_with('/integrations/payments/adyen')
    end
  end

  describe 'stored names' do
    it 'loads a payment method row as 5.x left it' do
      row = Spree::PaymentMethod.where(id: gateway.id).pick(:type)

      expect(row).to eq('SpreeAdyen::Gateway')
      expect(Spree::PaymentMethod.find(gateway.id)).to be_a(described_class)
    end

    it 'resolves both session classes by their stored names' do
      expect(gateway.payment_session_class).to eq('Spree::PaymentSessions::Adyen'.constantize)
      expect(gateway.payment_setup_session_class).to eq('Spree::PaymentSetupSessions::Adyen'.constantize)
      expect(Spree::PaymentSessions::Adyen.superclass).to eq(Spree::PaymentSession)
      expect(Spree::PaymentSetupSessions::Adyen.superclass).to eq(Spree::PaymentSetupSession)
    end
  end
end

RSpec.describe SpreeAdyen::Gateway, 'money verbs' do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }
  let(:payment) { adyen_session_payment(gateway: gateway) }
  let(:money) { Spree::Money.new(payment.amount, currency: payment.currency) }
  let(:minor_units) { SpreeAdyen::Amounts.to_adyen(payment.amount, payment.currency) }
  let(:captures_url) { "#{AdyenHelpers::CHECKOUT_URL}/payments/PSP0000000000001/captures" }
  let(:cancels_url) { "#{AdyenHelpers::CHECKOUT_URL}/payments/PSP0000000000001/cancels" }
  let(:refunds_url) { "#{AdyenHelpers::CHECKOUT_URL}/payments/PSP0000000000001/refunds" }

  before { allow_any_instance_of(described_class).to receive(:wait_before_retry) }

  def key(action, attempt)
    "spree-#{payment.prefixed_id}-#{action}-#{attempt}"
  end

  # The order number then the key, so staff find Spree's requests in the Customer Area.
  def reference(action, attempt)
    "#{payment.order.number}-#{key(action, attempt)}"
  end

  describe '#capture' do
    it 'requests a capture of the PSP reference and answers requested' do
      stub = stub_request(:post, captures_url).
             with(body: hash_including('merchantAccount' => gateway.preferred_merchant_account,
                                       'amount' => { 'value' => minor_units, 'currency' => payment.currency },
                                       'reference' => reference('capture', 0)),
                  headers: { 'Idempotency-Key' => key('capture', 0), 'X-Api-Key' => gateway.preferred_api_key }).
             to_return(adyen_json({ 'pspReference' => 'CAPTURE00000001', 'status' => 'received' }, status: 201))

      response = gateway.capture(money, payment.response_code, {})

      expect(stub).to have_been_requested.once
      expect(response).to be_success
      expect(response).to be_requested
      expect(response.authorization).to eq(payment.response_code)
      expect(response.reference).to eq('CAPTURE00000001')
    end

    it 'gets a new key once Adyen has answered an earlier attempt' do
      create(:payment_capture_event, :failed, payment: payment)
      stub = stub_request(:post, captures_url).with(headers: { 'Idempotency-Key' => key('capture', 1) }).
             to_return(adyen_json({ 'pspReference' => 'CAPTURE00000002' }, status: 201))

      gateway.capture(money, payment.response_code, {})

      expect(stub).to have_been_requested.once
    end

    it 'repeats the key when a call times out' do
      stub = stub_request(:post, captures_url).with(headers: { 'Idempotency-Key' => key('capture', 0) }).
             to_timeout.then.to_return(adyen_json({ 'pspReference' => 'CAPTURE00000003' }, status: 201))

      expect(gateway.capture(money, payment.response_code, {}).reference).to eq('CAPTURE00000003')
      expect(stub).to have_been_requested.twice
    end

    it 'retries a 5xx twice, then raises that the outcome is unknown' do
      stub = stub_request(:post, captures_url).to_return(adyen_json({ 'message' => 'Internal error' }, status: 500))

      expect { gateway.capture(money, payment.response_code, {}) }.to raise_error(Spree::Core::AmbiguousGatewayError, /did not answer/)
      expect(stub).to have_been_requested.times(3)
    end

    it "fails at once on a refusal, with Adyen's code and message" do
      stub = stub_request(:post, captures_url).
             to_return(adyen_json({ 'status' => 422, 'errorCode' => '167', 'message' => 'Original pspReference required for this operation' },
                                  status: 422))

      expect { gateway.capture(money, payment.response_code, {}) }.
        to raise_error(Spree::Core::GatewayError, 'Adyen refused the request: Original pspReference required for this operation (167)')
      expect(stub).to have_been_requested.once
    end

    it 'gets a new key after Adyen refused an attempt, rather than its old refusal' do
      stub_request(:post, captures_url).with(headers: { 'Idempotency-Key' => key('capture', 0) }).
        to_return(adyen_json({ 'errorCode' => '167', 'message' => 'Refused' }, status: 422))
      retried = stub_request(:post, captures_url).with(headers: { 'Idempotency-Key' => key('capture', 1) }).
                to_return(adyen_json({ 'pspReference' => 'CAPTURE00000005' }, status: 201))

      expect { gateway.capture(money, payment.response_code, {}) }.to raise_error(Spree::Core::GatewayError)
      expect(gateway.capture(money, payment.response_code, {}).reference).to eq('CAPTURE00000005')
      expect(retried).to have_been_requested.once
    end

    it 'logs a status line, never a body' do
      stub_request(:post, captures_url).to_return(adyen_json({ 'pspReference' => 'CAPTURE00000004' }, status: 201))
      allow(Rails.logger).to receive(:info)

      gateway.capture(money, payment.response_code, {})

      expect(Rails.logger).to have_received(:info).with('[spree_adyen] capture 201')
      expect(Rails.logger).not_to have_received(:info).with(/merchantAccount|CAPTURE00000004/)
    end

    it 'refuses a payment without a PSP reference, naming the Customer Area' do
      payment.update_columns(metadata: {})

      expect { gateway.capture(money, payment.response_code, {}) }.to raise_error(Spree::Core::GatewayError, /Customer Area/)
    end
  end

  describe '#void' do
    it 'requests a cancel, records its reference and answers requested' do
      stub = stub_request(:post, cancels_url).
             with(body: hash_including('reference' => reference('cancel', 0)), headers: { 'Idempotency-Key' => key('cancel', 0) }).
             to_return(adyen_json({ 'pspReference' => 'CANCEL000000001', 'status' => 'received' }, status: 201))

      response = gateway.void(payment.response_code, nil, {})

      expect(stub).to have_been_requested.once
      expect(response).to be_requested
      expect(payment.reload.metadata['adyen_cancel_references']).to eq(['CANCEL000000001'])
    end

    it 'gets a new key after a recorded cancel' do
      payment.update_columns(metadata: payment.metadata.merge('adyen_cancel_references' => ['CANCEL000000001']))
      stub = stub_request(:post, cancels_url).with(headers: { 'Idempotency-Key' => key('cancel', 1) }).
             to_return(adyen_json({ 'pspReference' => 'CANCEL000000002' }, status: 201))

      gateway.void(payment.response_code, nil, {})

      expect(stub).to have_been_requested.once
    end

    it 'refuses a payment without a PSP reference' do
      payment.update_columns(metadata: {})

      expect { gateway.void(payment.response_code, nil, {}) }.to raise_error(Spree::Core::GatewayError, /PSP reference/)
    end
  end

  describe '#credit' do
    let(:payment) { adyen_session_payment(gateway: gateway, status: 'completed') }

    it 'requests a refund keyed on the refunds before it, and answers requested with its reference' do
      create(:refund, payment: payment, amount: 1)
      refund = create(:refund, :requested, payment: payment, amount: 2, transaction_id: nil)
      stub = stub_request(:post, refunds_url).
             with(body: hash_including('amount' => { 'value' => SpreeAdyen::Amounts.to_adyen(2, payment.currency), 'currency' => payment.currency },
                                       'reference' => reference('refund', 1)),
                  headers: { 'Idempotency-Key' => key('refund', 1) }).
             to_return(adyen_json({ 'pspReference' => 'REFUND000000001', 'status' => 'received' }, status: 201))

      response = gateway.credit(Spree::Money.new(2, currency: payment.currency), nil, payment.response_code, originator: refund)

      expect(stub).to have_been_requested.once
      expect(response).to be_requested
      expect(response.authorization).to eq('REFUND000000001')
    end

    it 'repeats the key of a refund retried after a timeout' do
      refund = create(:refund, :requested, payment: payment, amount: 2, transaction_id: nil)
      stub = stub_request(:post, refunds_url).with(headers: { 'Idempotency-Key' => key('refund', 0) }).
             to_timeout.then.to_return(adyen_json({ 'pspReference' => 'REFUND000000002' }, status: 201))

      gateway.credit(Spree::Money.new(2, currency: payment.currency), nil, payment.response_code, originator: refund)

      expect(stub).to have_been_requested.twice
    end
  end

  describe '#cancel' do
    it 'voids an uncaptured payment' do
      stub_request(:post, cancels_url).to_return(adyen_json({ 'pspReference' => 'CANCEL000000003' }, status: 201))

      expect(gateway.cancel(payment.response_code, payment)).to be_requested
    end

    it 'refunds a completed payment through the refund workflow' do
      payment.update_columns(status: 'completed')
      stub_request(:post, refunds_url).to_return(adyen_json({ 'pspReference' => 'REFUND000000003' }, status: 201))

      expect(gateway.cancel(payment.response_code, payment)).to be_requested
      expect(payment.refunds.sole).to be_requested
    end

    it 'keeps the money of a completed payment when asked' do
      payment.update_columns(status: 'completed')

      expect(gateway.cancel(payment.response_code, payment, refund: false)).not_to be_requested
      expect(payment.refunds).to be_empty
    end
  end

  describe '#authorize' do
    it 'answers with the session id and makes no call' do
      response = gateway.authorize(money, nil, payment_prefixed_id: payment.prefixed_id)

      expect(response).to be_success
      expect(response.authorization).to eq(payment.response_code)
    end

    it 'refuses a payment with no session' do
      loose = create(:payment, payment_method: gateway, response_code: 'NOSESSION', source: nil, skip_source_requirement: true)

      expect { gateway.purchase(money, nil, payment_prefixed_id: loose.prefixed_id) }.
        to raise_error(Spree::Core::GatewayError, 'Adyen payments are taken through a payment session.')
    end
  end

  describe '#can_void?' do
    it 'is false for a completed payment, which is refunded instead' do
      expect(gateway.can_void?(build(:payment, status: 'completed'))).to be(false)
      expect(gateway.can_void?(build(:payment, status: 'pending'))).to be(true)
    end
  end

  describe '#gateway_dashboard_payment_url' do
    it "links to the payment's page in the test Customer Area" do
      expect(gateway.gateway_dashboard_payment_url(payment)).
        to eq('https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=PSP0000000000001&txType=Payment')
    end

    it 'links to the live Customer Area outside test mode' do
      gateway.preferred_test_mode = false

      expect(gateway.gateway_dashboard_payment_url(payment)).to start_with('https://ca-live.adyen.com/')
    end

    it 'is nil without a PSP reference' do
      payment.update_columns(metadata: {})

      expect(gateway.gateway_dashboard_payment_url(payment)).to be_nil
    end
  end

  describe '#credential_problem' do
    let(:merchants_url) { "#{AdyenHelpers::MANAGEMENT_URL}/merchants?pageSize=100" }
    let(:webhooks_url) { "#{AdyenHelpers::MANAGEMENT_URL}/merchants/#{gateway.preferred_merchant_account}/webhooks?pageSize=1" }

    it 'is nil when the credential reaches the merchant account with the webhook roles' do
      stub_request(:get, merchants_url).to_return(adyen_json({ 'data' => [{ 'id' => gateway.preferred_merchant_account }] }))
      stub_request(:get, webhooks_url).to_return(adyen_json({ 'data' => [] }))

      expect(gateway.credential_problem).to be_nil
    end

    it 'names a merchant account the credential cannot reach' do
      stub_request(:get, merchants_url).to_return(adyen_json({ 'data' => [{ 'id' => 'OtherECOM' }] }))

      expect(gateway.credential_problem).to include(gateway.preferred_merchant_account)
    end

    it 'names an invalid key' do
      stub_request(:get, merchants_url).to_return(adyen_json({ 'status' => 401 }, status: 401))

      expect(gateway.credential_problem).to include('rejected this API key')
    end

    it 'names a missing role' do
      stub_request(:get, merchants_url).to_return(adyen_json({ 'data' => [{ 'id' => gateway.preferred_merchant_account }] }))
      stub_request(:get, webhooks_url).to_return(adyen_json({ 'status' => 403 }, status: 403))

      expect(gateway.credential_problem).to include('Webhooks read and write')
    end
  end

  # Recorded against the test account by the author (Phase 15); never written
  # by a run. Each reads the ids it needs from the environment named in
  # spec/support/vcr.rb.
  describe 'against Adyen', :vcr do
    let(:psp_reference) { ENV.fetch('ADYEN_CAPTURE_PSP_REFERENCE', 'PSP_RECORDED_AUTHORISED') }
    let(:payment) { adyen_session_payment(gateway: gateway, psp_reference: psp_reference, amount: BigDecimal('10')) }
    let(:captured) do
      adyen_session_payment(gateway: gateway, status: 'completed', amount: BigDecimal('10'),
                            psp_reference: ENV.fetch('ADYEN_CAPTURED_PSP_REFERENCE', 'PSP_RECORDED_CAPTURED'))
    end

    it 'lists the configured merchant account', vcr: { cassette_name: 'merchants_reachable' } do
      expect(gateway.credential_problem).to be_nil
    end

    it 'names a merchant account the credential cannot reach', vcr: { cassette_name: 'merchants_unreachable' } do
      gateway.preferred_merchant_account = ENV.fetch('ADYEN_UNREACHABLE_MERCHANT_ACCOUNT', 'UnreachableECOM')

      expect(gateway.credential_problem).to include(gateway.preferred_merchant_account)
    end

    it 'names an invalid key', vcr: { cassette_name: 'credential_bad_key' } do
      gateway.preferred_api_key = 'AQE_invalid'

      expect(gateway.credential_problem).to include('rejected this API key')
    end

    it 'names a missing webhook role', vcr: { cassette_name: 'credential_missing_role' } do
      gateway.preferred_api_key = ENV.fetch('ADYEN_LIMITED_API_KEY', 'limited_api_key_test')

      expect(gateway.credential_problem).to include('Webhooks read and write')
    end

    it 'has a capture received', vcr: { cassette_name: 'capture_received' } do
      response = gateway.capture(Spree::Money.new(BigDecimal('10'), currency: payment.currency), payment.response_code, {})

      expect(response).to be_requested
      expect(response.reference).to be_present
    end

    it 'has a capture of a captured payment refused', vcr: { cassette_name: 'capture_refused' } do
      expect { gateway.capture(Spree::Money.new(BigDecimal('10'), currency: captured.currency), captured.response_code, {}) }.
        to raise_error(Spree::Core::GatewayError, /Adyen refused the request/)
    end

    it 'has a cancel received', vcr: { cassette_name: 'cancel_received' } do
      expect(gateway.void(payment.response_code, nil, {})).to be_requested
    end

    it 'has a cancel of a captured payment refused', vcr: { cassette_name: 'cancel_refused' } do
      expect { gateway.void(captured.response_code, nil, {}) }.to raise_error(Spree::Core::GatewayError, /Adyen refused the request/)
    end

    it 'has a full refund received', vcr: { cassette_name: 'refund_received' } do
      response = gateway.credit(Spree::Money.new(BigDecimal('10'), currency: captured.currency), nil, captured.response_code, {})

      expect(response).to be_requested
      expect(response.authorization).to be_present
    end

    it 'has a partial refund received', vcr: { cassette_name: 'refund_partial_received' } do
      expect(gateway.credit(Spree::Money.new(BigDecimal('4'), currency: captured.currency), nil, captured.response_code, {})).to be_requested
    end

    it 'has a refund above the captured amount refused', vcr: { cassette_name: 'refund_refused_amount' } do
      expect { gateway.credit(Spree::Money.new(BigDecimal('1000'), currency: captured.currency), nil, captured.response_code, {}) }.
        to raise_error(Spree::Core::GatewayError, /Adyen refused the request/)
    end
  end
end
