require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ShipmentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.shipments.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns shipments for the order' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns the shipment' do
      get :show, params: { order_id: order.prefixed_id, id: shipment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(shipment.prefixed_id)
      expect(json_response['number']).to eq(shipment.number)
      expect(json_response['state']).to eq(shipment.state)
    end
  end

  describe 'PATCH #update' do
    it 'updates shipment tracking' do
      patch :update, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id,
        tracking: '1Z999AA10123456784'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(shipment.reload.tracking).to eq('1Z999AA10123456784')
    end
  end

  describe 'PATCH #ship' do
    it 'marks the shipment as shipped' do
      shipment.ready! if shipment.can_ready?

      patch :ship, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['state']).to eq('shipped')
    end
  end

  describe 'PATCH #cancel' do
    it 'cancels the shipment' do
      patch :cancel, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['state']).to eq('canceled')
    end
  end

  describe 'PATCH #resume' do
    it 'resumes a canceled shipment' do
      shipment.cancel!

      patch :resume, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(%w[pending ready]).to include(json_response['state'])
    end
  end

  describe 'PATCH #split' do
    it 'splits items to a new shipment at a different stock location' do
      variant = shipment.inventory_units.first.variant
      target_stock_location = create(:stock_location, name: 'Warehouse 2')
      target_stock_location.stock_items.find_or_create_by(variant: variant).set_count_on_hand(10)

      patch :split, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id,
        variant_id: variant.prefixed_id,
        quantity: 1,
        stock_location_id: target_stock_location.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok), "Expected 200 but got #{response.status}: #{response.body}"
      expect(json_response['data']).to be_an(Array)
    end
  end
end
