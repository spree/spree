require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Cart::ItemsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let!(:order) { create(:order, user: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'adds a line item and returns updated cart' do
      expect do
        post :create, params: { variant_id: variant.prefixed_id, quantity: 2 }
      end.to change(Spree::LineItem, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('cart_')
      expect(json_response['item_count']).to eq(2)
    end

    it 'defaults quantity to 1' do
      post :create, params: { variant_id: variant.prefixed_id }

      expect(response).to have_http_status(:created)
      expect(json_response['item_count']).to eq(1)
    end

    it 'returns updated totals' do
      post :create, params: { variant_id: variant.prefixed_id, quantity: 2 }

      expect(json_response['item_total'].to_f).to be > 0
    end

    context 'with metadata' do
      it 'adds a line item with metadata' do
        post :create, params: {
          variant_id: variant.prefixed_id,
          quantity: 1,
          metadata: { 'gift_note' => 'Happy Birthday!' }
        }

        expect(response).to have_http_status(:created)
        line_item = order.reload.line_items.last
        expect(line_item.metadata).to eq({ 'gift_note' => 'Happy Birthday!' })
      end
    end

    context 'with spree token (guest)' do
      let(:guest_order) { create(:order, user: nil, store: store) }

      before { request.headers['Authorization'] = nil }

      it 'adds line item with valid spree token' do
        request.headers['x-spree-token'] = guest_order.token
        post :create, params: { variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:created)
      end

      it 'returns not found without spree token' do
        post :create, params: { variant_id: variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'validation errors' do
      it 'returns error for invalid variant' do
        post :create, params: { variant_id: 'invalid_0', quantity: 1 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    it 'updates line item quantity and returns updated cart' do
      patch :update, params: { id: line_item.prefixed_id, quantity: 5 }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to start_with('cart_')
      expect(line_item.reload.quantity).to eq(5)
    end

    it 'returns updated totals' do
      original_total = order.item_total
      patch :update, params: { id: line_item.prefixed_id, quantity: 5 }

      expect(json_response['item_total'].to_f).to be > original_total
    end

    context 'with metadata' do
      it 'updates line item metadata' do
        patch :update, params: {
          id: line_item.prefixed_id,
          metadata: { 'gift_note' => 'Happy Birthday!' }
        }

        expect(response).to have_http_status(:ok)
        expect(line_item.reload.metadata).to eq({ 'gift_note' => 'Happy Birthday!' })
      end

      it 'updates metadata and quantity together' do
        patch :update, params: {
          id: line_item.prefixed_id,
          quantity: 3,
          metadata: { 'gift_note' => 'Happy Birthday!' }
        }

        expect(response).to have_http_status(:ok)
        line_item.reload
        expect(line_item.quantity).to eq(3)
        expect(line_item.metadata).to eq({ 'gift_note' => 'Happy Birthday!' })
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        patch :update, params: { id: 'li_nonexistent', quantity: 5 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    it 'removes line item and returns updated cart' do
      expect do
        delete :destroy, params: { id: line_item.prefixed_id }
      end.to change(Spree::LineItem, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to start_with('cart_')
    end

    context 'error handling' do
      it 'returns not found for non-existent line item' do
        delete :destroy, params: { id: 'li_nonexistent' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
