require 'spec_helper'

module Spree
  describe Gateway::Bogus, type: :model do
    let(:bogus) { create(:credit_card_payment_method) }
    let!(:cc) { create(:credit_card, payment_method: bogus, gateway_customer_profile_id: 'BGS-RERTERT') }

    it 'disable recurring contract by destroying payment source' do
      bogus.disable_customer_profile(cc)
      expect(cc.gateway_customer_profile_id).to be_nil
    end

    describe '#gateway_dashboard_payment_url' do
      it 'links to the payment by its transaction id' do
        expect(bogus.gateway_dashboard_payment_url(build(:payment, response_code: 'BGS-123'))).to eq('https://dashboard.bogus.example/payments/BGS-123')
      end

      it 'returns nil before the payment is charged' do
        expect(bogus.gateway_dashboard_payment_url(build(:payment, response_code: nil))).to be_nil
      end
    end
  end
end
