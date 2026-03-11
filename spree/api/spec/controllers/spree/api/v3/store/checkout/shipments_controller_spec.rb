require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Checkout::ShipmentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) do
    create(:order_with_line_items, user: user, store: store, state: 'delivery').tap do |o|
      o.create_proposed_shipments
      o.shipments.first.refresh_rates
      o.reload
    end
  end
  let!(:shipment) { order.shipments.first }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns a list of shipments for the cart' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(order.shipments.count)
      expect(json_response['data'].first['id']).to eq(shipment.prefixed_id)
    end

    context 'with spree token (guest)' do
      let(:guest_order) do
        create(:order_with_line_items, user: nil, store: store, state: 'delivery').tap do |o|
          o.create_proposed_shipments
          o.reload
        end
      end

      before { request.headers['Authorization'] = nil }

      it 'returns shipments with valid spree token' do
        request.headers['x-spree-token'] = guest_order.token
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_present
      end

      it 'returns not found without spree token' do
        get :index

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
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

        expect(order.shipment_total).to eq(5)

        patch :update, params: {
          id: shipment.to_param,
          selected_shipping_rate_id: expensive_rate.to_param
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to start_with('cart_')
        order.reload
        expect(order.shipment_total).to eq(25)
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent shipping rate' do
        patch :update, params: {
          id: shipment.to_param,
          selected_shipping_rate_id: 'sr_invalid'
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
