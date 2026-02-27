require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    let(:order) { create(:order_with_line_items, user: user, store: store) }

    context 'authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns the order' do
        get :show, params: { id: order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(order.number)
        expect(json_response['state']).to eq(order.state)
      end

      it 'returns order with expected attributes' do
        get :show, params: { id: order.to_param }

        expect(json_response['id']).to eq(order.prefixed_id)
        expect(json_response['number']).to eq(order.number)
      end
    end

    context 'with order token' do
      let(:guest_order) { create(:order_with_line_items, user: nil, store: store) }

      it 'returns the order for guest with valid token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(guest_order.number)
      end

      it 'returns not found with invalid token' do
        request.headers['X-Spree-Order-Token'] = 'invalid'
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found without token' do
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns not found for invalid order number' do
        get :show, params: { id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users order' do
        other_order = create(:order_with_line_items, store: store)
        get :show, params: { id: other_order.to_param }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end

  describe 'PATCH #update' do
    let(:order) { create(:order_with_line_items, user: user, store: store) }

    context 'authenticated' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'updates the order email' do
        patch :update, params: { id: order.to_param, email: 'new@example.com' }

        expect(response).to have_http_status(:ok)
        expect(order.reload.email).to eq('new@example.com')
      end

      it 'updates special instructions' do
        patch :update, params: { id: order.to_param, special_instructions: 'Leave at door' }

        expect(response).to have_http_status(:ok)
        expect(order.reload.special_instructions).to eq('Leave at door')
      end

      it 'updates the order locale' do
        allow(store).to receive(:supported_locales_list).and_return(['en', 'fr'])

        patch :update, params: { id: order.to_param, locale: 'fr' }

        expect(response).to have_http_status(:ok)
        expect(order.reload.locale).to eq('fr')
        expect(json_response['locale']).to eq('fr')
      end

      it 'returns error when locale is not supported by store' do
        allow(store).to receive(:supported_locales_list).and_return(['en'])

        patch :update, params: { id: order.to_param, locale: 'de' }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'updates order metadata' do
        patch :update, params: {
          id: order.to_param,
          metadata: { 'source' => 'mobile_app', 'utm_campaign' => 'summer' }
        }

        expect(response).to have_http_status(:ok)
        expect(order.reload.metadata).to eq({ 'source' => 'mobile_app', 'utm_campaign' => 'summer' })
      end

      it 'merges metadata with existing values' do
        order.update!(private_metadata: { 'existing' => 'value' })

        patch :update, params: {
          id: order.to_param,
          metadata: { 'new_key' => 'new_value' }
        }

        expect(response).to have_http_status(:ok)
        expect(order.reload.metadata).to eq({ 'existing' => 'value', 'new_key' => 'new_value' })
      end

      it 'does not return metadata in response' do
        patch :update, params: {
          id: order.to_param,
          metadata: { 'source' => 'mobile_app' }
        }

        expect(response).to have_http_status(:ok)
        expect(json_response).not_to have_key('metadata')
        expect(json_response).not_to have_key('private_metadata')
      end
    end

    context 'with order token' do
      let(:guest_order) { create(:order_with_line_items, user: nil, store: store) }

      it 'updates order for guest with valid token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        patch :update, params: { id: guest_order.to_param, email: 'guest@example.com' }

        expect(response).to have_http_status(:ok)
        expect(guest_order.reload.email).to eq('guest@example.com')
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns not found for other users order' do
        other_order = create(:order_with_line_items, store: store)
        patch :update, params: { id: other_order.to_param, email: 'hack@example.com' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end
end
