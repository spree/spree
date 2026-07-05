require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::FulfillmentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.shipments.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns fulfillments for the order' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns the fulfillment' do
      get :show, params: { order_id: order.prefixed_id, id: shipment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(shipment.prefixed_id)
      expect(json_response['number']).to eq(shipment.number)
      expect(json_response['status']).to eq(shipment.state)
    end
  end

  describe 'POST #create' do
    it 'creates a fulfillment with every unfulfilled item when items are omitted' do
      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: shipment.stock_location.prefixed_id,
        tracking: 'INPOST-123'
      }, as: :json

      expect(response).to have_http_status(:created), "Expected 201 but got #{response.status}: #{response.body}"
      expect(json_response['id']).to start_with('ful_')
      expect(json_response['tracking']).to eq('INPOST-123')
      expect(json_response['items'].sum { |item| item['quantity'] }).to eq(order.line_items.sum(:quantity))
      expect(order.reload.shipments.count).to eq(1)
      expect(Spree::Shipment.exists?(shipment.id)).to be(false)
    end

    it 'creates a fulfillment for explicit items, keeping the source shipment' do
      other_order = create(:order_ready_to_ship, store: store, line_items_count: 2)
      line_item = other_order.line_items.first

      post :create, params: {
        order_id: other_order.prefixed_id,
        stock_location_id: other_order.shipments.first.stock_location.prefixed_id,
        items: [{ item_id: line_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['items']).to contain_exactly(
        'item_id' => line_item.prefixed_id, 'variant_id' => line_item.variant.prefixed_id, 'quantity' => 1
      )
      expect(other_order.reload.shipments.count).to eq(2)
    end

    it 'attaches the delivery method as the selected rate' do
      delivery_method = create(:shipping_method)

      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: shipment.stock_location.prefixed_id,
        delivery_method_id: delivery_method.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:created)
      fulfillment = order.reload.shipments.first
      expect(fulfillment.shipping_method).to eq(delivery_method)
    end

    it "registers an already-shipped fulfillment with status: 'shipped' and an explicit cost" do
      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: shipment.stock_location.prefixed_id,
        tracking: 'DPD-42',
        cost: '7.42',
        status: 'shipped'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('shipped')
      expect(json_response['fulfilled_at']).to be_present
      expect(BigDecimal(json_response['cost'])).to eq(BigDecimal('7.42'))
      expect(order.reload.shipment_state).to eq('shipped')
    end

    it 'returns 422 for a non-completed order' do
      draft_order = create(:order_with_line_items, store: store)

      post :create, params: {
        order_id: draft_order.prefixed_id,
        stock_location_id: draft_order.shipments.first.stock_location.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to eq(Spree.t('fulfillments.errors.order_not_completed'))
    end

    it 'returns 422 when the requested quantity exceeds the unfulfilled quantity' do
      line_item = order.line_items.first

      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: shipment.stock_location.prefixed_id,
        items: [{ item_id: line_item.prefixed_id, quantity: 99 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to include('exceeds its unfulfilled quantity')
    end

    it 'returns 422 for a malformed or non-positive quantity' do
      line_item = order.line_items.first

      ['abc', -1].each do |bad_quantity|
        post :create, params: {
          order_id: order.prefixed_id,
          stock_location_id: shipment.stock_location.prefixed_id,
          items: [{ item_id: line_item.prefixed_id, quantity: bad_quantity }]
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['message']).to include('must be a positive integer')
      end
    end

    it 'returns 404 for an item belonging to another order' do
      foreign_line_item = create(:order_ready_to_ship, store: store).line_items.first

      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: shipment.stock_location.prefixed_id,
        items: [{ item_id: foreign_line_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'updates fulfillment tracking' do
      patch :update, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id,
        tracking: '1Z999AA10123456784'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(shipment.reload.tracking).to eq('1Z999AA10123456784')
    end

    it 'selects a delivery rate by prefixed ID' do
      new_rate = create(:shipping_rate, shipment: shipment, cost: 20, selected: false)

      patch :update, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id,
        selected_delivery_rate_id: new_rate.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok), "Expected 200 but got #{response.status}: #{response.body}"
      expect(shipment.reload.selected_shipping_rate).to eq(new_rate)
    end

    it 'ignores a state parameter' do
      original_state = shipment.state

      patch :update, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id,
        state: 'shipped'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(shipment.reload.state).to eq(original_state)
      expect(shipment.state).not_to eq('shipped')
    end
  end

  describe 'PATCH #fulfill' do
    it 'marks the fulfillment as shipped' do
      shipment.ready! if shipment.can_ready?

      patch :fulfill, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('shipped')
    end
  end

  describe 'PATCH #cancel' do
    it 'cancels the fulfillment' do
      patch :cancel, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('canceled')
    end
  end

  describe 'PATCH #resume' do
    it 'resumes a canceled fulfillment' do
      shipment.cancel!

      patch :resume, params: {
        order_id: order.prefixed_id,
        id: shipment.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(%w[pending ready]).to include(json_response['status'])
    end
  end

  describe 'PATCH #split' do
    it 'splits items to a new fulfillment at a different stock location' do
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
