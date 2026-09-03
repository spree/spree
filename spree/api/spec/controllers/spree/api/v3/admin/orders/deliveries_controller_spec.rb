require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::DeliveriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:fulfillment) { order.fulfillments.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the consignments of the fulfillment' do
      get :index, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['tracking_number']).to eq(fulfillment.tracking)
      expect(json_response['data'].first['status']).to eq('pending')
    end
  end

  describe 'POST #create' do
    it 'records another consignment on the fulfillment' do
      post :create, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        tracking_number: '1Z879E930346834440'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('dlv_')
      expect(json_response['carrier']).to eq('ups')
      expect(json_response['carrier_name']).to eq('UPS')
      expect(fulfillment.reload.deliveries.count).to eq(2)
    end

    # A forwarder's PRO number belongs to a carrier the registry never heard
    # of and must still be enterable.
    it 'takes a free-text carrier and a pasted tracking link' do
      post :create, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        tracking_number: 'PRO-4471923', carrier: 'Estes Freight',
        tracking_url: 'https://forwarder.example/PRO-4471923'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['carrier']).to eq('Estes Freight')
      expect(json_response['tracking_url']).to eq('https://forwarder.example/PRO-4471923')
    end

    it 'refuses a duplicate number on the same fulfillment' do
      post :create, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        tracking_number: fulfillment.tracking
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'corrects the number and starts the carrier journey over' do
      delivery = fulfillment.deliveries.first
      delivery.update_columns(status: 'in_transit')

      patch :update, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        id: delivery.prefixed_id, tracking_number: 'CORRECTED-1'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['tracking_number']).to eq('CORRECTED-1')
      expect(json_response['status']).to eq('pending')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes a hand-entered consignment' do
      delivery = fulfillment.deliveries.first

      delete :destroy, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: delivery.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Delivery.exists?(delivery.id)).to be(false)
    end

    it 'refuses one a label minted' do
      label = create(:shipping_label, :with_delivery, owner: fulfillment)

      delete :destroy, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.delivery.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #mark_delivered' do
    before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

    it 'closes the consignment and rolls the fulfillment up' do
      patch :mark_delivered, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        id: fulfillment.deliveries.first.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('delivered')
      expect(fulfillment.reload).to be_delivered
    end

    it 'leaves the fulfillment fulfilled while a sibling is still travelling' do
      Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: 'BOX-2')

      patch :mark_delivered, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
        id: fulfillment.deliveries.first.prefixed_id
      }, as: :json

      expect(fulfillment.reload).to be_fulfilled
    end
  end

  # Every lookup runs through the store's own order, so an id from elsewhere
  # is missing rather than denied.
  it 'answers 404 for a fulfillment on another store order' do
    other = create(:order_ready_to_ship, store: create(:store))

    get :index, params: { order_id: other.prefixed_id, fulfillment_id: other.fulfillments.first.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
