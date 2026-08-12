# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::GatewayCustomer, type: :model do
  let(:store) { @default_store }

  describe '.for_provider' do
    let(:bogus_method) { create(:payment_method, type: 'Spree::Gateway::Bogus', store: store) }
    let(:check_method) { create(:payment_method, type: 'Spree::PaymentMethod::Check', store: store) }

    let!(:bogus_customer) { create(:gateway_customer, payment_method: bogus_method) }
    let!(:check_customer) { create(:gateway_customer, payment_method: check_method) }

    it 'returns only customers of the given provider' do
      expect(described_class.for_provider(Spree::Gateway::Bogus)).to contain_exactly(bogus_customer)
    end

    it 'accepts the provider as a string' do
      expect(described_class.for_provider('Spree::PaymentMethod::Check')).to contain_exactly(check_customer)
    end
  end
end
