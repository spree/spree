require 'spec_helper'

RSpec.describe Spree::PaymentSource, type: :model do
  let(:store) { @default_store }
  let(:payment_method) { create(:custom_payment_method, stores: [store]) }
  let(:payment_source) { create(:payment_source, user: user, payment_method: payment_method) }
  let(:user) { create(:user) }

  describe '#gateway_customer' do
    let!(:gateway_customer) { create(:gateway_customer, payment_method: payment_method, user: user) }

    context 'when user is present' do
      it 'returns the gateway customer for the user' do
        expect(payment_source.gateway_customer).to eq(gateway_customer)
      end
    end

    context 'when user is not present' do
      let(:payment_source) { create(:payment_source, user: nil, payment_method: payment_method) }

      it 'returns nil' do
        expect(payment_source.gateway_customer).to be_nil
      end
    end
  end
end
