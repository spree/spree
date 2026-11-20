require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::RefundsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:payment) { order.payments.first }
  let!(:refund_reason) { create(:refund_reason) }

  before do
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    let!(:refund) { create(:refund, payment: payment, amount: 10.0) }

    it 'returns refunds for the order' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'POST #create' do
    it 'creates a refund' do
      expect {
        post :create, params: {
          order_id: order.prefixed_id,
          payment_id: payment.prefixed_id,
          refund_reason_id: refund_reason.prefixed_id,
          amount: '5.00'
        }, as: :json
      }.to change(Spree::Refund, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['amount']).to eq('5.00')
    end

    # Store credit is its own ledger and writes no refund row, so a card refund
    # bounded by the payment alone gave back money the credit already had
    # (V-3832).
    context 'after a return was refunded as store credit' do
      let(:return_record) { create(:received_return, store: store) }
      let(:order) { return_record.order }
      let(:payment) { order.payments.completed.first }
      let(:credited) { return_record.refund_total }

      before do
        allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
        result = Spree::Returns::Refund.call(return_record: return_record, amount: credited, refund_method: 'store_credit')
        expect(result).to be_success
      end

      def refund(amount)
        post :create, params: {
          order_id: order.prefixed_id,
          payment_id: payment.prefixed_id,
          amount: Spree::Money::Rounding.format(amount, 'USD')
        }, as: :json
      end

      it 'refuses to refund the whole payment and records nothing' do
        expect { refund(payment.amount) }.not_to change(Spree::Refund, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['message']).to eq(I18n.t('spree.refund_exceeds_order_balance'))
      end

      it 'refunds what the store credit left' do
        expect { refund(payment.amount - credited) }.to change(Spree::Refund, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end
  end
end
