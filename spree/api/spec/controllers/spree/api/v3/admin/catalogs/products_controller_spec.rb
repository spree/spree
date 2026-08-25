require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the assortment in manual order' do
      first = create(:catalog_product, catalog: catalog)
      second = create(:catalog_product, catalog: catalog)
      second.move_to_top

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).
        to eq([second.product.prefixed_id, first.product.prefixed_id])
    end

    it '404s under another store catalog' do
      get :index, params: { catalog_id: create(:catalog, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'adds store products in bulk by prefixed id' do
      product = create(:product, store: store)

      post :create, params: { catalog_id: catalog.prefixed_id, product_ids: [product.prefixed_id] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['added_count']).to eq(1)
      expect(catalog.products.reload).to contain_exactly(product)
    end

    it 'silently drops products of another store' do
      foreign = create(:product, store: create(:store))

      post :create, params: { catalog_id: catalog.prefixed_id, product_ids: [foreign.prefixed_id] }, as: :json

      expect(json_response['added_count']).to eq(0)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes one product from the assortment' do
      entry = create(:catalog_product, catalog: catalog)

      delete :destroy, params: { catalog_id: catalog.prefixed_id, id: entry.product.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(catalog.catalog_products.reload).to be_empty
    end
  end

  describe 'PATCH #reposition' do
    it 'persists a drag-to-reorder' do
      first = create(:catalog_product, catalog: catalog)
      second = create(:catalog_product, catalog: catalog)

      patch :reposition, params: { catalog_id: catalog.prefixed_id, id: second.product.prefixed_id, new_position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(catalog.catalog_products.order(:position).map(&:id)).to eq([second.id, first.id])
    end
  end
end
