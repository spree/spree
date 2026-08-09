require 'spec_helper'

RSpec.describe SpreeStripe::CreatePayment do
  subject(:create_payment) { described_class.new(owner: order, payment_session: payment_session, gateway: gateway).call }

  let(:store) { @default_store }
  let!(:order) { create(:order_with_line_items, store: store) }
  let!(:gateway) { create(:stripe_gateway, store: store) }

  let(:payment_session) do
    create(:stripe_payment_session, owner: order, payment_method: gateway, external_id: payment_intent_id)
  end

  let!(:gateway_customer) do
    create(:gateway_customer, customer: order.customer, payment_method: gateway, profile_id: customer_id)
  end

  let(:payment_intent_id) { 'pi_3QY76s2ESifGlJez04sj0cMb' }
  let(:customer_id) { 'cus_RQdclxFVLH4oau' }
  let(:payment_method_id) { 'pm_1QY4zO2ESifGlJezkHIvUraY' }

  let(:payment) { order.payments.last }

  it 'creates a payment with the data from the Stripe charge' do
    VCR.use_cassette('retrieve_payment_intent_charge') do
      expect { subject }.to change { order.payments.count }.by(1).and change { Spree::CreditCard.count }.by(1)
    end

    expect(subject).to be_a Spree::Payment

    expect(payment.payment_method).to eq gateway
    expect(payment.amount).to eq order.total_minus_store_credits
    expect(payment.response_code).to eq(payment_intent_id)
    expect(payment.stripe_charge_id).to eq('ch_3QY76s2ESifGlJez0gG0FoF1')

    expect(payment.source).to be_a Spree::CreditCard
    expect(payment.source.gateway_payment_profile_id).to eq(payment_method_id)
    expect(payment.source.customer).to eq order.customer
    expect(payment.source.cc_type).to eq('visa')
    expect(payment.source.last_digits).to eq('4242')
    expect(payment.source.month).to eq(2)
    expect(payment.source.year).to eq(2027)

    expect(payment.avs_response).to eq('Y')
    expect(payment.cvv_response_code).to be_nil
  end

  it 'only creates the payment once' do
    VCR.use_cassette('retrieve_payment_intent_charge') do
      expect { subject }.to change { order.payments.count }.by(1)
      expect { described_class.new(owner: order, payment_session: payment_session, gateway: gateway).call }.
        not_to change { order.payments.count }
    end
  end

  context 'when the payment intent is a bank transfer' do
    let(:payment_intent_id) { 'pi_3ScPMjFmGsiQWfE61qMaWSFF' }
    let(:customer_id) { 'cus_TZFk4Fxe9gABNI' }
    let(:payment_method_id) { 'pm_1ScPNbFmGsiQWfE6IQ5cXwYc' }

    it 'builds the source from the intent, since there is no charge' do
      VCR.use_cassette('retrieve_payment_intent_bank_transfer') do
        expect { subject }.to change { order.payments.count }.by(1)
      end

      expect(payment.payment_method).to eq(gateway)
      expect(payment.amount).to eq(order.total_minus_store_credits)
      expect(payment.response_code).to eq(payment_intent_id)
      expect(payment.stripe_charge_id).to be_nil

      expect(payment.source).to be_a SpreeStripe::PaymentSources::BankTransfer
      expect(payment.source.gateway_payment_profile_id).to eq(payment_method_id)
    end
  end
end
