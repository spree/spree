require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ProductTypesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product_type) { create(:product_type, name: 'T-Shirt') }
  let(:option_type) { create(:option_type, name: 'size') }
  let(:category) { create(:category) }
  let(:definition) { create(:custom_field_definition, key: 'material') }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    before do
      product_type.option_types << option_type
      product_type.categories << category
      create(:product_type_custom_field_definition, :required, product_type: product_type,
                                                               custom_field_definition: definition, sort_order: 0)
    end

    it 'returns association ids as prefixed ids' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['option_type_ids']).to eq([option_type.prefixed_id])
      expect(json_response['category_ids']).to eq([category.prefixed_id])
    end

    it 'returns the custom field definitions with their usage' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      field = json_response['custom_field_definitions'].first
      expect(field['id']).to eq(definition.prefixed_id)
      expect(field['key']).to eq('material')
      expect(field['required']).to be(true)
      expect(field['sort_order']).to eq(0)
    end
  end

  describe 'PATCH #update' do
    it 'replaces the option types and categories' do
      patch :update, params: {
        id: product_type.prefixed_id,
        option_type_ids: [option_type.prefixed_id],
        category_ids: [category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product_type.reload.option_types).to eq([option_type])
      expect(product_type.categories).to eq([category])
    end

    it 'does not touch existing products' do
      product = create(:product)
      product.update_column(:product_type_id, product_type.id)

      patch :update, params: {
        id: product_type.prefixed_id,
        option_type_ids: [option_type.prefixed_id]
      }, as: :json

      expect(product.reload.option_types).to be_empty
    end

    it 'ignores categories from another store' do
      foreign_category = create(:category, store: create(:store))

      patch :update, params: {
        id: product_type.prefixed_id,
        category_ids: [foreign_category.prefixed_id]
      }, as: :json

      expect(product_type.reload.categories).to be_empty
    end

    it 'replaces the custom field definitions' do
      other_definition = create(:custom_field_definition, key: 'care')
      create(:product_type_custom_field_definition, product_type: product_type,
                                                    custom_field_definition: other_definition)

      patch :update, params: {
        id: product_type.prefixed_id,
        custom_field_definitions: [{ id: definition.prefixed_id, required: true, sort_order: 3 }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      joins = product_type.reload.product_type_custom_field_definitions
      expect(joins.map(&:custom_field_definition)).to eq([definition])
      expect(joins.first.required).to be(true)
      expect(joins.first.sort_order).to eq(3)
    end
  end

  describe 'POST #apply_to_products' do
    it 'enqueues the backfill job and reports the affected count' do
      create(:product, product_type: product_type)

      expect {
        post :apply_to_products, params: { id: product_type.prefixed_id }, as: :json
      }.to have_enqueued_job(Spree::ProductTypes::ApplyToProductsJob)

      expect(response).to have_http_status(:accepted)
      expect(json_response['products_count']).to eq(1)
    end
  end

  describe 'DELETE #destroy' do
    it 'refuses while products still use the type' do
      create(:product, product_type: product_type)

      delete :destroy, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Spree::ProductType.find_by(id: product_type.id)).to be_present
    end
  end
end
