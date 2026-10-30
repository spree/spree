require 'spec_helper'

RSpec.describe Spree::PaymentSource, type: :model do
  let(:store) { @default_store }
  let(:payment_method) { create(:custom_payment_method) }
  let(:payment_source) { create(:payment_source, customer: user, payment_method: payment_method) }
  let(:user) { create(:user) }

  describe 'validations' do
    let(:other_payment_method) { create(:custom_payment_method) }

    before { create(:payment_source, payment_method: payment_method, gateway_payment_profile_id: 'profile-1') }

    it 'rejects a duplicate gateway payment profile under the same payment method' do
      duplicate = build(:payment_source, payment_method: payment_method, gateway_payment_profile_id: 'profile-1')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:gateway_payment_profile_id]).to include('has already been taken')
    end

    it 'allows the same gateway payment profile under a different payment method' do
      other = build(:payment_source, payment_method: other_payment_method, gateway_payment_profile_id: 'profile-1')

      expect(other).to be_valid
    end
  end

  describe '#gateway_customer' do
    let!(:gateway_customer) { create(:gateway_customer, payment_method: payment_method, customer: user) }

    context 'when user is present' do
      it 'returns the gateway customer for the user' do
        expect(payment_source.gateway_customer).to eq(gateway_customer)
      end
    end

    context 'when user is not present' do
      let(:payment_source) { create(:payment_source, customer: nil, payment_method: payment_method) }

      it 'returns nil' do
        expect(payment_source.gateway_customer).to be_nil
      end
    end
  end
end
