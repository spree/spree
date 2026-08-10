require 'spec_helper'

RSpec.describe SpreeStripe::CustomerUpdatedSubscriber do
  subject(:handle) { described_class.new.handle(event) }

  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:event) { instance_double(Spree::Event, payload: { 'id' => customer.prefixed_id }) }

  context 'when the customer has a Stripe customer' do
    let(:gateway) { create(:stripe_gateway, store: store) }
    let!(:gateway_customer) do
      create(:gateway_customer, customer: customer, payment_method: gateway, profile_id: 'cus_123')
    end

    it 'pushes the change to Stripe' do
      expect_any_instance_of(SpreeStripe::Gateway).to receive(:update_customer).with(customer: customer)

      handle
    end
  end

  context 'when the customer has no Stripe customer' do
    it 'does not call Stripe' do
      expect_any_instance_of(SpreeStripe::Gateway).not_to receive(:update_customer)

      handle
    end
  end

  context 'when the customer no longer exists' do
    let(:event) { instance_double(Spree::Event, payload: { 'id' => 'user_nonexistent' }) }

    it 'does nothing' do
      expect { handle }.not_to raise_error
    end
  end
end
