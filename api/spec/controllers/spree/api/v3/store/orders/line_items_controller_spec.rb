require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::LineItemsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let(:order) { create(:order, user: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
    request.headers['x-spree-order-token'] = order.token
  end

  describe 'POST #create' do
    it 'adds a line item to the order' do
      expect do
        post :create, params: { order_id: order.to_param, line_item: { variant_id: variant.prefix_id, quantity: 2 } }
      end.to change(Spree::LineItem, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['variant_id']).to eq(variant.prefix_id)
      expect(json_response['quantity']).to eq(2)
    end

    it 'defaults quantity to 1' do
      post :create, params: { order_id: order.to_param, line_item: { variant_id: variant.prefix_id } }

      expect(response).to have_http_status(:created)
      expect(json_response['quantity']).to eq(1)
    end

    it 'updates order totals' do
      post :create, params: { order_id: order.to_param, line_item: { variant_id: variant.prefix_id, quantity: 2 } }

      expect(order.reload.item_total).to be > 0
    end

    context 'with order token (guest)' do
      let(:guest_order) { create(:order, store: store) }

      before { request.headers['Authorization'] = nil }

      it 'adds line item with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        post :create, params: { order_id: guest_order.to_param, line_item: { variant_id: variant.prefix_id, quantity: 1 } }

        expect(response).to have_http_status(:created)
      end

      it 'returns forbidden without order token' do
        post :create, params: { order_id: guest_order.to_param, line_item: { variant_id: variant.prefix_id, quantity: 1 } }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
        expect(json_response['error']['message']).to be_present
      end
    end

    context 'validation errors' do
      it 'returns error for invalid variant' do
        post :create, params: { order_id: order.to_param, line_item: { variant_id: 0, quantity: 1 } }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('variant_not_found')
        expect(json_response['error']['message']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        post :create, params: { order_id: 'invalid', line_item: { variant_id: variant.prefix_id, quantity: 1 } }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns forbidden for other users order' do
        other_order = create(:order, store: store)

        post :create, params: { order_id: other_order.to_param, line_item: { variant_id: variant.prefix_id, quantity: 1 } }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end
  end

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    it 'updates line item quantity' do
      patch :update, params: { order_id: order.to_param, id: line_item.prefix_id, line_item: { quantity: 5 } }

      expect(response).to have_http_status(:ok)
      expect(line_item.reload.quantity).to eq(5)
    end

    it 'updates order totals' do
      original_total = order.item_total
      patch :update, params: { order_id: order.to_param, id: line_item.prefix_id, line_item: { quantity: 5 } }

      expect(order.reload.item_total).to be > original_total
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        patch :update, params: { order_id: order.to_param, id: 0, line_item: { quantity: 5 } }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('line_item_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns forbidden for line item in other users order' do
        other_order = create(:order, store: store)
        other_line_item = create(:line_item, order: other_order, variant: variant)

        patch :update, params: { order_id: other_order.to_param, id: other_line_item.prefix_id, line_item: { quantity: 5 } }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    it 'removes line item from order' do
      expect do
        delete :destroy, params: { order_id: order.to_param, id: line_item.prefix_id }
      end.to change(Spree::LineItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'updates order totals' do
      order.update_columns(item_total: 100)
      delete :destroy, params: { order_id: order.to_param, id: line_item.prefix_id }

      expect(order.reload.item_total).to eq(0)
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        delete :destroy, params: { order_id: order.to_param, id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('line_item_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns forbidden for line item in other users order' do
        other_order = create(:order, store: store)
        other_line_item = create(:line_item, order: other_order, variant: variant)

        delete :destroy, params: { order_id: other_order.to_param, id: other_line_item.prefix_id }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
      end
    end
  end
end
