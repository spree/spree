require 'spec_helper'

module Spree
  describe Gateway::Bogus, type: :model do
    let(:bogus) { create(:credit_card_payment_method) }
    let!(:cc) { create(:credit_card, payment_method: bogus, gateway_customer_profile_id: 'BGS-RERTERT') }

    it 'disable recurring contract by destroying payment source' do
      bogus.disable_customer_profile(cc)
      expect(cc.gateway_customer_profile_id).to be_nil
    end

    describe 'requested mode' do
      it 'answers at once with the preference off' do
        expect(bogus.capture(1000, 'BGS-123', {})).not_to be_requested
        expect(bogus.void('BGS-123', cc, {})).not_to be_requested
        expect(bogus.credit(1000, cc, 'BGS-123', {})).not_to be_requested
      end

      context 'with the preference on' do
        before { bogus.preferred_requested_mode = true }

        it 'answers a capture as requested, with a reference' do
          response = bogus.capture(1000, 'BGS-123', {})

          expect(response).to be_success
          expect(response).to be_requested
          expect(response.reference).to start_with('BGS-capture-')
        end

        it 'answers a void as requested' do
          expect(bogus.void('BGS-123', cc, {})).to be_requested
        end

        it 'answers a refund as requested, with its reference as the authorization' do
          response = bogus.credit(1000, cc, 'BGS-123', {})

          expect(response).to be_requested
          expect(response.authorization).to start_with('BGS-refund-')
        end
      end
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
