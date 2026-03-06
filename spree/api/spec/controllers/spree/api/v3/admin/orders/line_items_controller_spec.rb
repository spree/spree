require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::LineItemsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order, store: store, state: 'cart') }
  let!(:variant) { create(:variant, product: create(:product, stores: [store])) }

  describe 'GET #index' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    subject { get :index, params: { order_id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns line items' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 2 }, as: :json }

    before { request.headers.merge!(headers) }

    it 'adds a line item' do
      expect { subject }.to change(order.line_items, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['quantity']).to eq(2)
    end
  end

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, quantity: 5 }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the line item quantity' do
      subject

      expect(response).to have_http_status(:ok)
      expect(line_item.reload.quantity).to eq(5)
    end
  end

  describe 'DELETE #destroy' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    subject { delete :destroy, params: { order_id: order.prefixed_id, id: line_item.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'removes the line item' do
      subject
      expect(response).to have_http_status(:no_content)
    end
  end
end
