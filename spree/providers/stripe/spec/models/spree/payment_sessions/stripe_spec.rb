require 'spec_helper'

RSpec.describe Spree::PaymentSessions::Stripe, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:order) { create(:order_with_line_items, store: store, customer: customer) }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:payment_session) do
    create(:stripe_payment_session,
           owner: order,
           payment_method: gateway,
           external_id: 'pi_test_abc123',
           external_data: {
             'client_secret' => 'pi_secret_xyz',
             'ephemeral_key_secret' => 'ek_test_key',
             'stripe_payment_method_id' => 'pm_card_visa'
           },
           customer_external_id: 'cus_test_123')
  end

  describe 'STI' do
    it 'uses the correct type' do
      expect(payment_session.type).to eq('Spree::PaymentSessions::Stripe')
    end

    it 'is a PaymentSession' do
      expect(payment_session).to be_a(Spree::PaymentSession)
    end
  end

  describe '#owner' do
    it 'returns the order when the session belongs to an order' do
      expect(payment_session.owner).to eq(order)
      expect(payment_session.cart).to be_nil
    end

    context 'when the owner is a cart' do
      let(:cart) { create(:cart_with_line_items, store: store, customer: customer) }
      let(:payment_session) { create(:stripe_payment_session, owner: cart, payment_method: gateway) }

      it 'returns the cart' do
        expect(payment_session.owner).to eq(cart)
        expect(payment_session.order).to be_nil
      end
    end
  end

  describe '#stripe_id' do
    it 'aliases external_id' do
      expect(payment_session.stripe_id).to eq('pi_test_abc123')
    end
  end

  describe '#client_secret' do
    it 'reads from external_data' do
      expect(payment_session.client_secret).to eq('pi_secret_xyz')
    end

    it 'returns nil when external_data is nil' do
      payment_session.external_data = nil
      expect(payment_session.client_secret).to be_nil
    end
  end

  describe '#ephemeral_key_secret' do
    it 'reads from external_data' do
      expect(payment_session.ephemeral_key_secret).to eq('ek_test_key')
    end
  end

  describe '#stripe_payment_intent' do
    let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_test_abc123', status: 'succeeded') }

    it 'retrieves from Stripe via payment_method' do
      expect(gateway).to receive(:retrieve_payment_intent).with('pi_test_abc123').and_return(stripe_pi)
      expect(payment_session.stripe_payment_intent).to eq(stripe_pi)
    end

    it 'caches the result' do
      expect(gateway).to receive(:retrieve_payment_intent).once.and_return(stripe_pi)
      2.times { payment_session.stripe_payment_intent }
    end
  end

  describe '#stripe_charge' do
    let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_test_abc123', status: 'succeeded', latest_charge: 'ch_123') }
    let(:stripe_charge) { Stripe::StripeObject.construct_from(id: 'ch_123') }

    before do
      allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
    end

    it 'retrieves charge from Stripe' do
      expect(gateway).to receive(:retrieve_charge).with('ch_123').and_return(stripe_charge)
      expect(payment_session.stripe_charge).to eq(stripe_charge)
    end

    it 'returns nil when no latest_charge' do
      allow(stripe_pi).to receive(:latest_charge).and_return(nil)
      expect(payment_session.stripe_charge).to be_nil
    end
  end

  describe '#accepted?' do
    let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_test_abc123', status: 'succeeded', payment_method: { type: 'card' }) }

    it 'delegates to payment_method' do
      allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      expect(payment_session.accepted?).to be true
    end
  end

  describe '#successful?' do
    it 'returns true when stripe status is succeeded' do
      stripe_pi = Stripe::StripeObject.construct_from(id: 'pi_test_abc123', status: 'succeeded')
      allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      expect(payment_session.successful?).to be true
    end

    it 'returns false when stripe status is not succeeded' do
      stripe_pi = Stripe::StripeObject.construct_from(id: 'pi_test_abc123', status: 'requires_payment_method')
      allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      expect(payment_session.successful?).to be false
    end
  end

  describe '#find_or_create_payment!' do
    before do
      allow(gateway).to receive(:create_profile)
    end

    it 'returns nil when not persisted' do
      session = build(:stripe_payment_session, owner: order, payment_method: gateway)
      expect(session.find_or_create_payment!).to be_nil
    end

    it 'returns existing payment if present' do
      payment = create(:payment, order: order, payment_method: gateway, response_code: payment_session.external_id, amount: payment_session.amount)
      expect(payment_session.reload.find_or_create_payment!).to eq(payment)
    end

    it 'creates payment via CreatePayment service' do
      mock_payment = build(:payment, order: order, payment_method: gateway)
      service = instance_double(SpreeStripe::CreatePayment, call: mock_payment)
      expect(SpreeStripe::CreatePayment).to receive(:new).with(
        owner: order,
        payment_session: payment_session,
        gateway: gateway,
        amount: payment_session.amount
      ).and_return(service)

      expect(payment_session.find_or_create_payment!).to eq(mock_payment)
    end

    it 'accepts metadata argument without error' do
      mock_payment = build(:payment, order: order, payment_method: gateway)
      service = instance_double(SpreeStripe::CreatePayment, call: mock_payment)
      allow(SpreeStripe::CreatePayment).to receive(:new).and_return(service)

      expect(payment_session.find_or_create_payment!(charge_id: 'ch_123')).to eq(mock_payment)
    end
  end

  describe 'state machine' do
    it 'starts as pending' do
      expect(payment_session.status).to eq('pending')
    end

    it 'can transition through the full lifecycle' do
      expect(payment_session.process).to be true
      expect(payment_session.complete).to be true
      expect(payment_session.status).to eq('completed')
    end
  end

  describe '#api_options' do
    it 'delegates to payment_method' do
      expect(payment_session.api_options).to eq(gateway.api_options)
    end
  end
end
