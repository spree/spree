require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::PaymentSessionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, customer: user, store: store) }
  let(:payment_method) { create(:bogus_payment_method) }
  let!(:payment_session) do
    create(:bogus_payment_session,
           order: order,
           payment_method: payment_method,
           amount: order.total,
           external_data: { 'client_secret' => 'secret_123' })
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'creates a payment session owned by the draft order' do
      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('pending')
      expect(json_response['order_id']).to eq(order.prefixed_id)
      expect(json_response['cart_id']).to be_nil
      expect(json_response['amount']).to eq(Spree::Money::Rounding.format(order.total_minus_store_credits, order.currency))
    end

    it 'rejects a payment method unavailable for the order' do
      allow_any_instance_of(payment_method.class).to receive(:available_for_order?).and_return(false)

      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('payment_method_unavailable')
    end

    it 'does not accept a staff-only payment method' do
      payment_method.update!(storefront_visible: false)

      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    context 'with the order token (guest)' do
      let(:guest_order) { create(:order_with_line_items, customer: nil, store: store) }

      before { request.headers['Authorization'] = nil }

      it 'creates a payment session' do
        request.headers['x-spree-token'] = guest_order.token

        post :create, params: { order_id: guest_order.prefixed_id, payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:created)
        expect(json_response['order_id']).to eq(guest_order.prefixed_id)
      end

      it 'returns not found without the token' do
        post :create, params: { order_id: guest_order.prefixed_id, payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found with another token' do
        request.headers['x-spree-token'] = 'wrong-token'

        post :create, params: { order_id: guest_order.prefixed_id, payment_method_id: payment_method.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns not found for another customer’s draft' do
      other_order = create(:order_with_line_items, customer: create(:user), store: store)

      post :create, params: { order_id: other_order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a draft in another store' do
      other_order = create(:order_with_line_items, customer: user, store: create(:store))

      post :create, params: { order_id: other_order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a placed order' do
      order.update_columns(status: 'placed', completed_at: Time.current)

      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    # A checkout's own draft belongs to its cart, which takes the payment.
    it 'returns not found for the transient draft of a checkout' do
      cart = create(:cart_with_line_items, customer: user, store: store)
      order.update_columns(cart_id: cart.id)

      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses when the access policy refuses writes' do
      allow_any_instance_of(Spree::Storefront::AccessPolicy).to receive(:writable?).and_return(false)

      post :create, params: { order_id: order.prefixed_id, payment_method_id: payment_method.prefixed_id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET #show' do
    it 'returns a payment session' do
      get :show, params: { order_id: order.prefixed_id, id: payment_session.to_param }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_session.prefixed_id)
      expect(json_response['external_data']).to eq({ 'client_secret' => 'secret_123' })
    end

    it 'finds a payment session by external_id' do
      get :show, params: { order_id: order.prefixed_id, id: payment_session.external_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_session.prefixed_id)
    end

    it 'returns not found for another order’s payment session' do
      other_session = create(:bogus_payment_session,
                             order: create(:order_with_line_items, customer: user, store: store),
                             payment_method: payment_method)

      get :show, params: { order_id: order.prefixed_id, id: other_session.to_param }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'updates the payment session' do
      patch :update, params: { order_id: order.prefixed_id, id: payment_session.to_param, amount: '50.00' }

      expect(response).to have_http_status(:ok)
      expect(json_response['amount']).to eq('50.00')
    end

    it 'returns not found once the order is placed' do
      order.update_columns(status: 'placed', completed_at: Time.current)

      patch :update, params: { order_id: order.prefixed_id, id: payment_session.to_param, amount: '50.00' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #complete' do
    it 'completes the payment session' do
      patch :complete, params: { order_id: order.prefixed_id, id: payment_session.to_param, session_result: 'success' }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
    end

    # A webhook can place the order before the buyer returns from the gateway.
    it 'still resolves once a webhook placed the order' do
      payment_session.update_column(:status, 'completed')
      order.update_columns(status: 'placed', completed_at: Time.current)

      patch :complete, params: { order_id: order.prefixed_id, id: payment_session.to_param, session_result: 'success' }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
    end
  end
end
