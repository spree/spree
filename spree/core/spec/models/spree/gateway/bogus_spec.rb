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

    describe '#parse_webhook_event' do
      let!(:payment) { create(:payment, payment_method: bogus, status: 'requested', response_code: 'BGS-PAY') }

      it 'is not implemented with requested mode off' do
        expect { bogus.parse_webhook_event('{}', {}) }.to raise_error(NotImplementedError)
      end

      context 'in requested mode' do
        before { bogus.update!(preferred_requested_mode: true) }

        def parse(body)
          bogus.parse_webhook_event(body.to_json, {})
        end

        it 'names the record by its reference, without looking it up' do
          expect(parse(action: 'capture_failed', reference: 'BGS-capture-1', reason: 'Expired')).
            to eq(action: :capture_failed, reference: 'BGS-capture-1', metadata: { 'reason' => 'Expired' })
        end

        it 'does not act on an unknown action or a missing reference' do
          expect(parse(action: 'captured', reference: 'BGS-capture-1')).to be_nil
          expect(parse(action: 'refund_succeeded')).to be_nil
        end

        it 'refuses a body that is not JSON' do
          expect { bogus.parse_webhook_event('not json', {}) }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
        end
      end
    end

    # PaymentMethod's default, which Bogus keeps.
    describe '#modification_record' do
      let!(:payment) { create(:payment, payment_method: bogus, status: 'requested', response_code: 'BGS-PAY') }

      it 'finds the capture event by its transaction id' do
        event = create(:payment_capture_event, :requested, payment: payment, transaction_id: 'BGS-capture-1')

        expect(bogus.modification_record(:capture_failed, 'BGS-capture-1')).to eq(event)
      end

      it 'finds a payment waiting on its void, or already void, by its response code' do
        expect(bogus.modification_record(:void_succeeded, 'BGS-PAY')).to eq(payment)

        payment.update_columns(status: 'void')
        expect(bogus.modification_record(:void_succeeded, 'BGS-PAY')).to eq(payment)

        payment.update_columns(status: 'pending')
        expect(bogus.modification_record(:void_succeeded, 'BGS-PAY')).to be_nil
      end

      it 'finds the refund by its transaction id' do
        refund = create(:refund, :requested, amount: 10, payment: create(:payment, payment_method: bogus, status: 'completed'),
                                             transaction_id: 'BGS-refund-1')

        expect(bogus.modification_record(:refund_succeeded, 'BGS-refund-1')).to eq(refund)
      end

      it "answers nil for a record not written yet, or another method's" do
        create(:payment, status: 'requested', response_code: 'BGS-OTHER')

        expect(bogus.modification_record(:capture_succeeded, 'BGS-capture-2')).to be_nil
        expect(bogus.modification_record(:void_succeeded, 'BGS-OTHER')).to be_nil
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
