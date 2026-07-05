require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::PaymentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    let(:check_payment_method) { create(:check_payment_method) }

    it 'creates a payment with a non-session payment method' do
      post :create, params: { cart_id: order.prefixed_id, payment_method_id: check_payment_method.prefixed_id }

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to be_present
      expect(json_response['status']).to eq('checkout')
      expect(json_response['payment_method_id']).to eq(check_payment_method.prefixed_id)
    end

    it 'creates a payment with a custom amount' do
      post :create, params: { cart_id: order.prefixed_id, payment_method_id: check_payment_method.prefixed_id, amount: '50.00' }

      expect(response).to have_http_status(:created)
      expect(json_response['amount']).to eq('50.0')
    end

    it 'creates a payment with metadata' do
      post :create, params: {
        cart_id: order.prefixed_id,
        payment_method_id: check_payment_method.prefixed_id,
        metadata: { purchase_order_number: 'PO-12345' }
      }

      expect(response).to have_http_status(:created)
      payment = Spree::Payment.find_by_prefix_id(json_response['id'])
      expect(payment.metadata['purchase_order_number']).to eq('PO-12345')
    end

    it 'rejects session-required payment methods' do
      bogus_method = create(:bogus_payment_method)

      post :create, params: { cart_id: order.prefixed_id, payment_method_id: bogus_method.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('payment_session_required')
    end

    it 'rejects unavailable payment methods' do
      unavailable_method = create(:check_payment_method)
      allow_any_instance_of(Spree::PaymentMethod::Check).to receive(:available_for_order?).and_return(false)

      post :create, params: { cart_id: order.prefixed_id, payment_method_id: unavailable_method.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('payment_method_unavailable')
    end

    it 'returns not found for invalid payment method' do
      post :create, params: { cart_id: order.prefixed_id, payment_method_id: 'pm_invalid' }

      expect(response).to have_http_status(:not_found)
    end

    context 'with spree token (guest)' do
      let(:guest_order) { create(:order_with_line_items, user: nil, store: store, state: 'payment') }

      before { request.headers['Authorization'] = nil }

      it 'creates a payment with valid spree token' do
        request.headers['x-spree-token'] = guest_order.token
        post :create, params: { cart_id: guest_order.prefixed_id, payment_method_id: check_payment_method.prefixed_id }

        expect(response).to have_http_status(:created)
        expect(json_response['payment_method_id']).to eq(check_payment_method.prefixed_id)
      end
    end
  end
end
