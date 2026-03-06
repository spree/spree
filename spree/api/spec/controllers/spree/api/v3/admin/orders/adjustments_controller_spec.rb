require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::AdjustmentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order, store: store, state: 'cart') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:adjustment) { create(:adjustment, adjustable: order, order: order, amount: 5.00, label: 'Admin discount') }

    it 'returns adjustments for the order' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'POST #create' do
    it 'creates a manual adjustment' do
      expect {
        post :create, params: {
          order_id: order.prefixed_id,
          amount: -5.00,
          label: 'Admin discount'
        }, as: :json
      }.to change(order.adjustments, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['amount']).to eq('-5.0')
      expect(json_response['label']).to eq('Admin discount')
    end
  end

  describe 'PATCH #update' do
    let!(:adjustment) { create(:adjustment, adjustable: order, order: order, amount: 5.00, label: 'Original') }

    it 'updates the adjustment' do
      patch :update, params: {
        order_id: order.prefixed_id,
        id: adjustment.prefixed_id,
        amount: 10.00,
        label: 'Updated'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['amount']).to eq('10.0')
      expect(json_response['label']).to eq('Updated')
    end
  end

  describe 'DELETE #destroy' do
    let!(:adjustment) { create(:adjustment, adjustable: order, order: order, amount: 5.00, label: 'To delete') }

    it 'deletes the adjustment' do
      expect {
        delete :destroy, params: {
          order_id: order.prefixed_id,
          id: adjustment.prefixed_id
        }, as: :json
      }.to change(order.adjustments, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
