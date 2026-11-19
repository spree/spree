require 'spec_helper'

RSpec.describe SpreeAdyen::Gateway, 'payment setup sessions' do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, :configured, store: store) }
  let(:customer) { create(:customer) }
  let(:return_url) { 'https://shop.example.com/account/cards' }

  before { create(:allowed_origin, store: store, origin: 'https://shop.example.com') }

  describe '#create_payment_setup_session' do
    it "opens a zero-amount session in the store's default currency that saves the card" do
      stub = stub_request(:post, "#{AdyenHelpers::CHECKOUT_URL}/sessions").
             with(body: hash_including('amount' => { 'value' => 0, 'currency' => store.default_market.currency },
                                       'shopperReference' => "customer_#{customer.id}", 'storePaymentMethodMode' => 'enabled')).
             to_return(adyen_json({ 'id' => 'CSSETUP000000001', 'sessionData' => 'Ab02b4c0!SETUP' }, status: 201))

      setup_session = gateway.create_payment_setup_session(customer: customer, external_data: { 'return_url' => return_url })

      expect(stub).to have_been_requested
      expect(setup_session).to have_attributes(external_id: 'CSSETUP000000001', status: 'pending', customer: customer)
      expect(setup_session.external_data).to include('session_data' => 'Ab02b4c0!SETUP', 'client_key' => 'test_CLIENTKEY')
    end

    it 'refuses a return URL outside the allowed origins' do
      expect { gateway.create_payment_setup_session(customer: customer, external_data: { 'return_url' => 'https://evil.example.com' }) }.
        to raise_error(Spree::Core::GatewayError, /allowed origins/)
    end
  end

  describe '#complete_payment_setup_session' do
    let(:setup_session) { create(:adyen_payment_setup_session, customer: customer, payment_method: gateway) }
    let(:result_url) { "#{AdyenHelpers::CHECKOUT_URL}/sessions/#{setup_session.external_id}?sessionResult=RESULT" }

    def result(stored_id)
      additional_data = { 'cardSummary' => '4242', 'expiryDate' => '03/2030' }
      additional_data['tokenization.storedPaymentMethodId'] = stored_id if stored_id
      { 'status' => 'completed', 'payments' => [{ 'pspReference' => 'PSPSETUP00000001', 'resultCode' => 'Authorised',
                                                  'paymentMethod' => { 'type' => 'scheme', 'brand' => 'visa' },
                                                  'additionalData' => additional_data }] }
    end

    it 'saves the card and completes' do
      stub_request(:get, result_url).to_return(adyen_json(result('STORED00000003')))

      gateway.complete_payment_setup_session(setup_session: setup_session, params: { 'session_result' => 'RESULT' })

      expect(setup_session.reload).to be_completed
      expect(setup_session.payment_source).to have_attributes(gateway_payment_profile_id: 'STORED00000003', customer: customer, last_digits: '4242')
    end

    it 'fails without a stored payment method id, naming the token' do
      stub_request(:get, result_url).to_return(adyen_json(result(nil)))

      completed = gateway.complete_payment_setup_session(setup_session: setup_session, params: { 'session_result' => 'RESULT' })

      expect(completed.errors[:base]).to include(I18n.t('spree.adyen.payment_session_errors.token_missing'))
      expect(setup_session.reload).to be_failed
      expect(setup_session.payment_source).to be_nil
    end
  end

  describe 'against Adyen', :vcr do
    it 'creates a setup session', vcr: { cassette_name: 'setup_session_create' } do
      expect(gateway.create_payment_setup_session(customer: customer, external_data: { 'return_url' => return_url })).to be_persisted
    end
  end
end
