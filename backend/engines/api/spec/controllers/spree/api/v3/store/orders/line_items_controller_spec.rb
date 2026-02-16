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
    it 'adds a line item and returns updated order' do
      expect do
        post :create, params: { order_id: order.to_param, variant_id: variant.prefixed_id, quantity: 2 }
      end.to change(Spree::LineItem, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to eq(order.prefixed_id)
      expect(json_response['number']).to eq(order.number)
      expect(json_response['item_count']).to eq(2)
    end

    it 'defaults quantity to 1' do
      post :create, params: { order_id: order.to_param, variant_id: variant.prefixed_id }

      expect(response).to have_http_status(:created)
      expect(json_response['item_count']).to eq(1)
    end

    it 'returns updated totals' do
      post :create, params: { order_id: order.to_param, variant_id: variant.prefixed_id, quantity: 2 }

      expect(json_response['item_total'].to_f).to be > 0
    end

    context 'with order token (guest)' do
      let(:guest_order) { create(:order, user: nil, store: store) }

      before { request.headers['Authorization'] = nil }

      it 'adds line item with valid order token' do
        request.headers['X-Spree-Order-Token'] = guest_order.token
        post :create, params: { order_id: guest_order.to_param, variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:created)
      end

      it 'returns not found without order token' do
        post :create, params: { order_id: guest_order.to_param, variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'validation errors' do
      it 'returns error for invalid variant' do
        post :create, params: { order_id: order.to_param, variant_id: 0, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('variant_not_found')
        expect(json_response['error']['message']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent order' do
        post :create, params: { order_id: 'invalid', variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users order' do
        other_order = create(:order, store: store)

        post :create, params: { order_id: other_order.to_param, variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    it 'updates line item quantity and returns updated order' do
      patch :update, params: { order_id: order.to_param, id: line_item.prefixed_id, quantity: 5 }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
      expect(json_response['number']).to eq(order.number)
      expect(line_item.reload.quantity).to eq(5)
    end

    it 'returns updated totals' do
      original_total = order.item_total
      patch :update, params: { order_id: order.to_param, id: line_item.prefixed_id, quantity: 5 }

      expect(json_response['item_total'].to_f).to be > original_total
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        patch :update, params: { order_id: order.to_param, id: 0, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('line_item_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for line item in other users order' do
        other_order = create(:order, store: store)
        other_line_item = create(:line_item, order: other_order, variant: variant)

        patch :update, params: { order_id: other_order.to_param, id: other_line_item.prefixed_id, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    it 'removes line item and returns updated order' do
      expect do
        delete :destroy, params: { order_id: order.to_param, id: line_item.prefixed_id }
      end.to change(Spree::LineItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
      expect(json_response['number']).to eq(order.number)
    end

    it 'updates order totals' do
      order.update_columns(item_total: 100)
      delete :destroy, params: { order_id: order.to_param, id: line_item.prefixed_id }

      expect(order.reload.item_total).to eq(0)
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        delete :destroy, params: { order_id: order.to_param, id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('line_item_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for line item in other users order' do
        other_order = create(:order, store: store)
        other_line_item = create(:line_item, order: other_order, variant: variant)

        delete :destroy, params: { order_id: other_order.to_param, id: other_line_item.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end
  end
end
