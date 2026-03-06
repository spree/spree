require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::PaymentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order_with_payment) { create(:order_ready_to_ship, store: store) }
  let!(:payment) { order_with_payment.payments.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns payments for the order' do
      get :index, params: { order_id: order_with_payment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to be >= 1
    end
  end

  describe 'GET #show' do
    it 'returns the payment' do
      get :show, params: { order_id: order_with_payment.prefixed_id, id: payment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment.prefixed_id)
      expect(json_response['state']).to be_present
    end
  end

  describe 'POST #create' do
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:payment_method) { create(:check_payment_method, stores: [store]) }

    it 'creates a payment' do
      post :create, params: {
        order_id: order.prefixed_id,
        payment_method_id: payment_method.id,
        amount: order.total
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['state']).to be_present
    end
  end

  describe 'PATCH #capture' do
    before do
      payment.update_column(:state, 'pending') if payment.state != 'pending'
    end

    it 'captures the payment' do
      patch :capture, params: {
        order_id: order_with_payment.prefixed_id,
        id: payment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH #void' do
    it 'voids the payment' do
      patch :void, params: {
        order_id: order_with_payment.prefixed_id,
        id: payment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
