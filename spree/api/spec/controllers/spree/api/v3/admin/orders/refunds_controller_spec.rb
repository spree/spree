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

    # A return refunded as store credit writes no refund row, so the card
    # payment's own balance still reads as if nothing had gone back.
    context 'when part of the order was already returned as store credit' do
      let!(:order) { create(:shipped_order, store: store) }
      let(:credited) { BigDecimal('4.00') }

      before do
        return_record = create(:received_return, store: store, order: order)
        result = Spree::Returns::Refund.call(return_record: return_record, amount: credited, refund_method: 'store_credit')
        raise result.error.to_s unless result.success?
      end

      it 'refuses a card refund of the full payment' do
        expect {
          post :create, params: {
            order_id: order.prefixed_id,
            payment_id: payment.prefixed_id,
            amount: payment.amount.to_s
          }, as: :json
        }.not_to change(Spree::Refund, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'refunds what the store credit left' do
        remaining = payment.amount - credited

        post :create, params: {
          order_id: order.prefixed_id,
          payment_id: payment.prefixed_id,
          amount: remaining.to_s
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(BigDecimal(json_response['amount'])).to eq(remaining)
      end
    end
  end
end
