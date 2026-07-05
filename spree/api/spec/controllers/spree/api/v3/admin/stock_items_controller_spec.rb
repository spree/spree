require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockItemsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }
  let!(:variant) { create(:variant) }
  let!(:stock_item) { variant.stock_items.find_by(stock_location: stock_location) || create(:stock_item, variant: variant, stock_location: stock_location) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns stock items' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |s| s['id'] }).to include(stock_item.prefixed_id)
    end

    it 'filters by stock_location_id' do
      other_location = create(:stock_location)
      _other_item = create(:stock_item, stock_location: other_location)

      get :index, params: { q: { stock_location_id_eq: stock_location.id } }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |s| s['id'] }
      expect(ids).to include(stock_item.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'updates count_on_hand' do
      patch :update, params: { id: stock_item.prefixed_id, count_on_hand: 42 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_item.reload.count_on_hand).to eq(42)
    end

    it 'toggles backorderable' do
      patch :update, params: { id: stock_item.prefixed_id, backorderable: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_item.reload.backorderable).to be true
    end

    it 'ignores variant_id and stock_location_id' do
      other_variant = create(:variant)
      other_location = create(:stock_location)

      patch :update, params: {
        id: stock_item.prefixed_id,
        variant_id: other_variant.prefixed_id,
        stock_location_id: other_location.prefixed_id,
        count_on_hand: 7
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_item.reload.variant_id).to eq(variant.id)
      expect(stock_item.stock_location_id).to eq(stock_location.id)
      expect(stock_item.count_on_hand).to eq(7)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the stock item' do
      target = create(:stock_item, stock_location: create(:stock_location))

      expect { delete :destroy, params: { id: target.prefixed_id }, as: :json }.
        to change(Spree::StockItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
