require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CatalogsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store catalogs with product counts' do
      create(:catalog_product, catalog: catalog)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cat_')
      expect(row['name']).to eq('Wholesale')
      expect(row['products_count']).to eq(1)
    end

    it 'hides catalogs belonging to another store' do
      other = create(:catalog, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'creates a catalog with a price list' do
      price_list = create(:price_list, store: store)

      post :create, params: { name: 'VIP', price_list_id: price_list.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['price_list_id']).to eq(price_list.prefixed_id)
    end

    it '404s a price list from another store' do
      foreign = create(:price_list, store: create(:store))

      post :create, params: { name: 'VIP', price_list_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #import_products' do
    it 'copies the price list products into the assortment' do
      product = create(:product, store: store, price: 100)
      price_list = create(:price_list, store: store).tap { |list| list.add_products([product.id]) }
      catalog.update!(price_list: price_list)

      post :import_products, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['added_count']).to eq(1)
      expect(catalog.products.reload).to contain_exactly(product)
    end

    it '422s without a price list' do
      post :import_products, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST #assign' do
    it 'assigns the catalog to a company node' do
      company = create(:company, store: store)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['assignable_type']).to eq('company')
      expect(json_response['assignable_id']).to eq(company.prefixed_id)
      expect(json_response['assignable_name']).to eq(company.name)
    end

    it 'assigns to a customer group' do
      group = create(:customer_group, store: store)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'customer_group', assignable_id: group.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
    end

    it '404s an audience from another store' do
      foreign = create(:company, store: create(:store))

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s an unknown audience type' do
      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'order', assignable_id: 'x' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a duplicate assignment' do
      company = create(:company, store: store)
      create(:catalog_assignment, catalog: catalog, assignable: company)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the catalog with its assortment and assignments' do
      create(:catalog_product, catalog: catalog)
      create(:catalog_assignment, catalog: catalog, assignable: create(:company, store: store))

      delete :destroy, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CatalogProduct.count).to eq(0)
      expect(Spree::CatalogAssignment.count).to eq(0)
    end
  end
end
