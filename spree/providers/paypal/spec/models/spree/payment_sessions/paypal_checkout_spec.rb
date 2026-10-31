require 'spec_helper'

RSpec.describe Spree::PaymentSessions::PaypalCheckout do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store) }
  let(:cart) { create(:cart_with_line_items, store: store) }
  let(:payment_session) { create(:paypal_checkout_payment_session, owner: cart, payment_method: gateway, external_id: 'ORDER1234567890AB') }

  it 'keeps the 5.x stored class name' do
    expect(described_class.name).to eq('Spree::PaymentSessions::PaypalCheckout')
  end

  it 'reads the client id and intent the gem wrote' do
    expect(payment_session.external_data['client_id']).to eq('paypal_client_id_test')
    expect(payment_session.intent).to eq('CAPTURE')
  end

  describe '#attempt' do
    it 'starts at one' do
      expect(payment_session.attempt).to eq(1)
    end

    it 'reads the stored attempt' do
      payment_session.external_data = payment_session.external_data.merge('attempt' => 3)

      expect(payment_session.attempt).to eq(3)
    end
  end

  describe '#complete_attempted?' do
    it 'is false before Complete asked PayPal for anything' do
      expect(payment_session).not_to be_complete_attempted
    end

    it 'is true once an attempt is recorded' do
      payment_session.external_data = payment_session.external_data.merge('attempt' => 1)

      expect(payment_session).to be_complete_attempted
    end
  end

  describe '#prepare_for_settlement!' do
    it 'fetches the PayPal order once, outside the lock' do
      allow(gateway).to receive(:paypal_order).and_return(paypal_order_data)

      payment_session.prepare_for_settlement!
      payment_session.paypal_order

      expect(gateway).to have_received(:paypal_order).once.with('ORDER1234567890AB')
    end

    it 'asks PayPal for nothing once the session has its payment' do
      create(:payment, cart: cart, order: nil, payment_method: gateway, amount: cart.total, response_code: 'ORDER1234567890AB')
      allow(gateway).to receive(:paypal_order)

      payment_session.prepare_for_settlement!

      expect(gateway).not_to have_received(:paypal_order)
    end
  end

  describe 'settlement' do
    before { payment_session.paypal_order = paypal_order_data(captures: [paypal_capture], extra: { 'payment_source' => source }) }

    let(:source) { { 'venmo' => { 'email_address' => 'buyer@example.com', 'account_id' => 'VENMO123', 'user_name' => 'buyer' } } }

    it 'builds the PayPal source from the order' do
      built = payment_session.payment_source_for_settlement

      expect(built.wallet).to eq('venmo')
      expect(built.email).to eq('buyer@example.com')
    end

    it 'records the capture id' do
      payment = Spree::Payment.new
      payment_session.apply_settlement_metadata(payment, { 'note' => 'kept' })

      expect(payment.metadata).to eq('note' => 'kept', 'paypal_capture_id' => 'CAPTURE123456789A')
    end

    it 'records the authorization id' do
      payment_session.paypal_order = paypal_order_data(authorizations: [paypal_authorization])
      payment = Spree::Payment.new
      payment_session.apply_settlement_metadata(payment, {})

      expect(payment.metadata).to eq('paypal_authorization_id' => 'AUTHORIZ123456789')
    end
  end
end
