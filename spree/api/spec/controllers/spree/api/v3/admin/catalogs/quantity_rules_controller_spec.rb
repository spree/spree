require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::QuantityRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }
  let(:variant) { create(:variant, product: create(:product, store: store)) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it "lists the catalog's overrides with the variant they name" do
      rule = create(:catalog_quantity_rule, catalog: catalog, variant: variant)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to eq(rule.prefixed_id)
      expect(row['variant_id']).to eq(variant.prefixed_id)
      expect(row['minimum_order_quantity']).to eq(48)
    end

    it "does not leak another catalog's rules" do
      other = create(:catalog, store: store)
      create(:catalog_quantity_rule, catalog: other, variant: variant)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(json_response['data']).to be_empty
    end
  end

  describe 'POST #create' do
    it 'records an override' do
      post :create, params: {
        catalog_id: catalog.prefixed_id,
        variant_id: variant.prefixed_id,
        minimum_order_quantity: 480,
        order_multiple: 240
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(catalog.quantity_rules.reload.first.minimum_order_quantity).to eq(480)
    end

    it 'refuses a row stating neither field' do
      post :create, params: { catalog_id: catalog.prefixed_id, variant_id: variant.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A variant belonging to another tenant must be unreachable, not merely
    # rejected by a validation.
    it 'is not found for a variant from another store' do
      foreign = create(:variant, product: create(:product, store: create(:store)))

      post :create, params: {
        catalog_id: catalog.prefixed_id, variant_id: foreign.prefixed_id, minimum_order_quantity: 12
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'changes the stated terms' do
      rule = create(:catalog_quantity_rule, catalog: catalog, variant: variant)

      patch :update, params: { catalog_id: catalog.prefixed_id, id: rule.prefixed_id, order_multiple: 12 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.order_multiple).to eq(12)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the override' do
      rule = create(:catalog_quantity_rule, catalog: catalog, variant: variant)

      delete :destroy, params: { catalog_id: catalog.prefixed_id, id: rule.prefixed_id }, as: :json

      expect(catalog.quantity_rules.reload).to be_empty
    end
  end

  describe 'a catalog in another store' do
    it 'is not found' do
      foreign = create(:catalog, store: create(:store))

      get :index, params: { catalog_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
