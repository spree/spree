require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::ProductTermsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }
  let(:product) { create(:product, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it "lists a catalog's terms at product grain" do
      catalog.add_products([product.id])
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant,
                                     minimum_order_quantity: 48, order_multiple: 24)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['product_id']).to eq(product.prefixed_id)
      expect(row['minimum_order_quantity']).to eq(48)
    end

    # The rows are per variant, so a product whose variants disagree is
    # reported honestly rather than by picking one of them.
    it 'marks a product whose variants carry different terms as mixed' do
      second = create(:variant, product: product)
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant,
                                     minimum_order_quantity: 48)
      create(:catalog_quantity_rule, catalog: catalog, variant: second, minimum_order_quantity: 96)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(json_response['data'].first['mixed']).to be(true)
    end
  end

  describe 'PUT #upsert' do
    it 'states terms for a product and adds it to the assortment' do
      put :upsert, params: {
        catalog_id: catalog.prefixed_id,
        terms: { product.prefixed_id => { minimum_order_quantity: 48, order_multiple: 24 } }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(catalog.products.reload).to include(product)
      expect(catalog.quantity_rules.reload.first.minimum_order_quantity).to eq(48)
    end

    it 'clears a product\'s terms when both fields are blank' do
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant)

      put :upsert, params: {
        catalog_id: catalog.prefixed_id,
        terms: { product.prefixed_id => { minimum_order_quantity: nil, order_multiple: nil } }
      }, as: :json

      expect(catalog.quantity_rules.reload).to be_empty
    end

    it 'is not found for a product from another store' do
      foreign = create(:product, store: create(:store))

      put :upsert, params: {
        catalog_id: catalog.prefixed_id,
        terms: { foreign.prefixed_id => { minimum_order_quantity: 48 } }
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'a catalog in another store' do
    it 'is not found' do
      get :index, params: { catalog_id: create(:catalog, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
