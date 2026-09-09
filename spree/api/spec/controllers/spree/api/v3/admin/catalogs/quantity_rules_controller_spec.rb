require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::QuantityRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }
  let(:product) { create(:product, store: store) }

  before { request.headers.merge!(headers) }

  # The whole set in one request, at the grain a merchant states terms at.
  # Reading them back is the assortment listing's job — see the products
  # controller spec (docs/plans/6.0-volume-pricing.md).
  describe 'PUT #upsert' do
    it 'states terms for a product and adds it to the assortment' do
      put :upsert, params: {
        catalog_id: catalog.prefixed_id,
        terms: { product.prefixed_id => { minimum_order_quantity: 48, order_multiple: 24 } }
      }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(catalog.products.reload).to include(product)
      expect(catalog.quantity_rules.reload.first.minimum_order_quantity).to eq(48)
    end

    it 'writes the stated pair to every variant of the product' do
      second = create(:variant, product: product)

      put :upsert, params: {
        catalog_id: catalog.prefixed_id,
        terms: { product.prefixed_id => { minimum_order_quantity: 48 } }
      }, as: :json

      expect(catalog.quantity_rules.reload.map(&:variant_id)).
        to match_array([product.default_variant.id, second.id])
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
      put :upsert, params: {
        catalog_id: create(:catalog, store: create(:store)).prefixed_id,
        terms: { product.prefixed_id => { minimum_order_quantity: 48 } }
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
