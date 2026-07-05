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
          amount: 5.00
        }, as: :json
      }.to change(Spree::Refund, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['amount']).to eq('5.0')
    end
  end
end
