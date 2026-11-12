require 'spec_helper'

RSpec.describe Spree::PaymentSetupSessions::Stripe, type: :model do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:setup_session) do
    create(:stripe_payment_setup_session,
           customer: customer,
           payment_method: gateway,
           external_id: 'seti_test_abc123',
           external_client_secret: 'seti_test_abc123_secret_xyz',
           external_data: { 'customer_id' => 'cus_test_123' })
  end

  describe '#stripe_setup_intent' do
    let(:stripe_setup_intent) { Stripe::StripeObject.construct_from(id: 'seti_test_abc123', status: 'succeeded') }

    it 'retrieves the SetupIntent from Stripe via payment_method' do
      expect(gateway).to receive(:retrieve_setup_intent).with('seti_test_abc123').and_return(stripe_setup_intent)
      expect(setup_session.stripe_setup_intent).to eq(stripe_setup_intent)
    end

    it 'caches the result' do
      expect(gateway).to receive(:retrieve_setup_intent).once.and_return(stripe_setup_intent)
      2.times { setup_session.stripe_setup_intent }
    end
  end

  describe '#successful?' do
    it 'returns true when stripe status is succeeded' do
      stripe_setup_intent = Stripe::StripeObject.construct_from(id: 'seti_test_abc123', status: 'succeeded')
      allow(gateway).to receive(:retrieve_setup_intent).and_return(stripe_setup_intent)
      expect(setup_session.successful?).to be true
    end

    it 'returns false when stripe status is not succeeded' do
      stripe_setup_intent = Stripe::StripeObject.construct_from(id: 'seti_test_abc123', status: 'requires_payment_method')
      allow(gateway).to receive(:retrieve_setup_intent).and_return(stripe_setup_intent)
      expect(setup_session.successful?).to be false
    end
  end
end
