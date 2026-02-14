require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::ShipmentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) do
    create(:order_with_line_items, user: user, store: store, state: 'delivery').tap do |o|
      o.create_proposed_shipments
      o.shipments.first.refresh_rates
      o.reload
    end
  end
  let(:shipment) { order.shipments.first }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
    request.headers['X-Spree-Order-Token'] = order.token
  end

  describe 'GET #index' do
    it 'returns a list of shipments for the order' do
      get :index, params: { order_id: order.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(order.shipments.count)
      expect(json_response['data'].first['id']).to eq(shipment.prefixed_id)
    end

    context 'with order token (guest)' do
      let(:guest_order) do
        create(:order_with_line_items, user: nil, store: store, state: 'delivery').tap do |o|
          o.create_proposed_shipments
          o.reload
        end
      end

      before { request.headers['Authorization'] = nil }

      it 'returns shipments with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_present
      end

      it 'returns not found without order token' do
        request.headers['X-Spree-Order-Token'] = nil
        get :index, params: { order_id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        get :index, params: { order_id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for other users order' do
        other_order = create(:order_with_line_items, store: store)
        request.headers['X-Spree-Order-Token'] = nil

        get :index, params: { order_id: other_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end

  describe 'GET #show' do
    it 'returns a single shipment' do
      get :show, params: { order_id: order.to_param, id: shipment.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(shipment.prefixed_id)
      expect(json_response['state']).to eq(shipment.state)
    end

    context 'error handling' do
      it 'returns not found for non-existent shipment' do
        get :show, params: { order_id: order.to_param, id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for shipment from another order' do
        other_order = create(:order_with_line_items, user: user, store: store).tap do |o|
          o.create_proposed_shipments
          o.reload
        end
        other_shipment = other_order.shipments.first

        get :show, params: { order_id: order.to_param, id: other_shipment.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'PATCH #update' do
    let(:shipping_rate) { shipment.shipping_rates.first }

    it 'selects a shipping rate' do
      skip 'Shipping rate setup requires more complex factory' unless shipping_rate.present?

      patch :update, params: {
        order_id: order.to_param,
        id: shipment.to_param,
        selected_shipping_rate_id: shipping_rate.to_param
      }

      expect(response).to have_http_status(:ok)
      expect(shipment.reload.selected_shipping_rate_id).to eq(shipping_rate.id)
    end

    context 'when selecting a different shipping rate' do
      let(:cheaper_shipping_method) { create(:shipping_method, name: 'Cheap Shipping') }
      let(:expensive_shipping_method) { create(:shipping_method, name: 'Express Shipping') }

      before do
        shipment.shipping_rates.delete_all
        create(:shipping_rate, shipment: shipment, shipping_method: cheaper_shipping_method, cost: 5, selected: true)
        create(:shipping_rate, shipment: shipment, shipping_method: expensive_shipping_method, cost: 25, selected: false)
        shipment.reload
        order.set_shipments_cost
      end

      it 'updates order totals when a different shipping rate is selected' do
        expensive_rate = shipment.shipping_rates.find_by(shipping_method: expensive_shipping_method)
        original_shipment_total = order.shipment_total

        expect(original_shipment_total).to eq(5)

        patch :update, params: {
          order_id: order.to_param,
          id: shipment.to_param,
          selected_shipping_rate_id: expensive_rate.to_param
        }

        expect(response).to have_http_status(:ok)
        order.reload
        expect(order.shipment_total).to eq(25)
        expect(order.total).to eq(order.item_total + 25 + order.adjustment_total)
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent shipping rate' do
        patch :update, params: {
          order_id: order.to_param,
          id: shipment.to_param,
          selected_shipping_rate_id: 'invalid'
        }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
