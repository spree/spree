require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::FulfillmentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:shipping_method) { create(:shipping_method) }
  let!(:order) do
    create(:cart_with_line_items, customer: user, store: store).tap do |o|
      o.update!(email: user.email, ship_address: create(:address))
      o.rebuild_fulfillments!
      o.fulfillments.first.refresh_rates
      o.set_fulfillments_cost
      o.reload
    end
  end
  let!(:fulfillment) { order.fulfillments.first }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'PATCH #update' do
    context 'when selecting a different delivery rate' do
      let(:cheaper_shipping_method) { create(:shipping_method, name: 'Cheap Shipping') }
      let(:expensive_shipping_method) { create(:shipping_method, name: 'Express Shipping') }

      before do
        fulfillment.delivery_rates.delete_all
        create(:shipping_rate, shipment: fulfillment, shipping_method: cheaper_shipping_method, cost: 5, selected: true)
        create(:shipping_rate, shipment: fulfillment, shipping_method: expensive_shipping_method, cost: 25, selected: false)
        fulfillment.reload
        order.set_fulfillments_cost
      end

      it 'updates cart totals when a different delivery rate is selected' do
        expensive_rate = fulfillment.delivery_rates.find_by(shipping_method: expensive_shipping_method)

        expect(order.delivery_total).to eq(5)

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: expensive_rate.to_param
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to start_with('cart_')
        order.reload
        expect(order.delivery_total).to eq(25)
      end
    end

    context 'auto-advance after rate selection' do
      it 'advances the cart from delivery to payment' do
        rate = fulfillment.delivery_rates.first

        expect(order.current_checkout_step).to eq('payment').or eq('delivery')

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['current_step']).to eq('payment')
      end

      it 'does not fail if advancement is not possible' do
        rate = fulfillment.delivery_rates.first

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
      end

      it 'does not complete the cart' do
        create(:store_credit_payment_method)
        credit = create(:store_credit, user: order.user, store: store, amount: order.total)
        order.payments.create!(
          source: credit,
          payment_method: Spree::PaymentMethod::StoreCredit.first,
          amount: (order.total / 2).to_d,
          response_code: credit.generate_authorization_code
        )
        rate = fulfillment.delivery_rates.first

        patch :update, params: {
          cart_id: order.prefixed_id,
          id: fulfillment.to_param,
          selected_delivery_rate_id: rate.to_param
        }

        expect(response).to have_http_status(:ok)
        order.reload
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
