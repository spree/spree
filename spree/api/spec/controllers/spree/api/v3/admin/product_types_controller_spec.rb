require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ProductTypesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product_type) { create(:product_type, name: 'T-Shirt', store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store product types' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['name'] }).to include('T-Shirt')
    end

    it 'does not leak other stores types' do
      create(:product_type, name: 'Foreign', store: create(:store))

      get :index, params: {}, as: :json

      expect(json_response['data'].map { |row| row['name'] }).not_to include('Foreign')
    end
  end

  describe 'POST #create' do
    it 'creates a product type with fulfillment types' do
      post :create, params: { name: 'Collectable', fulfillment_types: %w[shipping pickup] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Collectable')
      expect(json_response['fulfillment_types']).to eq(%w[shipping pickup])

      created = Spree::ProductType.find_by(name: 'Collectable')
      expect(created.store).to eq(store)
    end
  end

  describe 'PATCH #update' do
    it 'updates fulfillment types' do
      patch :update, params: { id: product_type.prefixed_id, fulfillment_types: %w[shipping pickup] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product_type.reload.fulfillment_types).to eq(%w[shipping pickup])
    end
  end

  describe 'DELETE #destroy' do
    it 'refuses while products still use the type' do
      create(:product, product_type: product_type, store: store)

      delete :destroy, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(product_type.reload).to be_present
    end

    it 'deletes an unused type' do
      delete :destroy, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::ProductType.find_by(id: product_type.id)).to be_nil
    end
  end
end
