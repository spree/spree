require 'spec_helper'

RSpec.describe SpreeStripe::UpdateCustomer do
  subject { described_class.new.call(customer: customer) }

  let(:customer) { create(:customer) }
  let(:store) { @default_store }

  before do
    allow(Stripe::Customer).to receive(:update).and_return(double(id: 'cus_123'))
  end

  context 'when the customer has a Stripe gateway customer' do
    let!(:stripe_gateway) { create(:stripe_gateway, store: store) }
    let!(:gateway_customer) { create(:gateway_customer, customer: customer, payment_method: stripe_gateway, profile_id: 'cus_123') }

    it 'updates the Stripe customer' do
      subject
      expect(Stripe::Customer).to have_received(:update).with('cus_123', anything, anything)
    end
  end

  context 'when the customer only has non-Stripe gateway customers' do
    let!(:credit_card_payment_method) { create(:credit_card_payment_method, store: store) }
    let!(:gateway_customer) do
      create(:gateway_customer, customer: customer, payment_method: credit_card_payment_method, profile_id: 'other_123')
    end

    it 'does not update the Stripe customer' do
      subject
      expect(Stripe::Customer).not_to have_received(:update)
    end
  end

  context 'when the customer has no gateway customers at all' do
    it 'does not update the Stripe customer' do
      subject
      expect(Stripe::Customer).not_to have_received(:update)
    end
  end
end
