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

  describe 'GET #show' do
    let!(:adjustment) { create(:adjustment, adjustable: order, order: order, amount: 5.00, label: 'Admin discount') }

    it 'returns the adjustment' do
      get :show, params: { order_id: order.prefixed_id, id: adjustment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(adjustment.prefixed_id)
    end
  end
end
