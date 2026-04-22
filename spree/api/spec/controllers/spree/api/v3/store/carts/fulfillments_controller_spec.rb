require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::FulfillmentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) do
    create(:order_with_line_items, user: user, store: store, state: 'delivery').tap do |o|
      o.create_proposed_shipments
      o.shipments.first.refresh_rates
      o.reload
    end
  end
  let!(:fulfillment) { order.shipments.first }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'PATCH #update' do
    context 'when selecting a different delivery rate' do
      let(:cheaper_shipping_method) { create(:shipping_method, name: 'Cheap Shipping') }
      let(:expensive_shipping_method) { create(:shipping_method, name: 'Express Shipping') }

      before do
        fulfillment.shipping_rates.delete_all
        create(:shipping_rate, shipment: fulfillment, shipping_method: cheaper_shipping_method, cost: 5, selected: true)
        create(:shipping_rate, shipment: fulfillment, shipping_method: expensive_shipping_method, cost: 25, selected: false)
        fulfillment.reload
        order.set_shipments_cost
      end

      it 'updates order totals when a different delivery rate is selected' do
        expensive_rate = fulfillment.shipping_rates.find_by(shipping_method: expensive_shipping_method)

        expect(order.shipment_total).to eq(5)

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: expensive_rate.to_param
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to start_with('cart_')
        order.reload
        expect(order.shipment_total).to eq(25)
      end
    end

    context 'auto-advance after rate selection' do
      it 'advances order from delivery to payment' do
        rate = fulfillment.shipping_rates.first

        expect(order.state).to eq('delivery')

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
        expect(order.reload.state).to eq('payment')
        expect(json_response['current_step']).to eq('payment')
      end

      it 'does not fail if advancement is not possible' do
        order.update_column(:state, 'address')
        rate = fulfillment.shipping_rates.first

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
      end

      it 'does not advance from payment to complete' do
        create(:store_credit_payment_method)
        credit = create(:store_credit, user: order.user, store: store, amount: order.total)
        order.payments.create!(
          source: credit,
          payment_method: Spree::PaymentMethod::StoreCredit.first,
          amount: (order.total / 2).to_d,
          state: 'checkout',
          response_code: credit.generate_authorization_code
        )
        rate = fulfillment.shipping_rates.first

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
        order.reload
        expect(order.state).to eq('payment')
        expect(order.completed_at).to be_nil
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent delivery rate' do
        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: 'dr_invalid'
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
