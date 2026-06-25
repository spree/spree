require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TranslationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }

  before do
    configure_supported_locales(store, %w[en de fr])
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    before { Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine') } }

    it 'returns the translation matrix, fields, and locales for the parent' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data']
      expect(data['resource_type']).to eq('product')
      expect(data['resource_id']).to eq(product.prefixed_id)
      expect(data['default_locale']).to eq('en')
      expect(data['supported_locales']).to match_array(%w[en de fr])
      expect(data['translations']['de']['name']).to eq('Espressomaschine')

      name_field = data['fields'].find { |f| f['key'] == 'name' }
      expect(name_field['source']).to eq('Espresso Machine')
      expect(name_field['type']).to eq('string')
    end

    it 'returns 404 for a missing parent' do
      get :index, params: { product_id: 'prod_NotReal' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the parent has translatable children (option type → values)' do
    let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }
    let!(:option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type) }

    it 'nests each option value matrix under the option type translations' do
      Mobility.with_locale(:de) { option_value.update!(presentation: 'Klein') }

      get :index, params: { option_type_id: option_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response['data']
      expect(data['resource_type']).to eq('option_type')
      expect(data['fields'].first['key']).to eq('label')

      child = data['children'].find { |c| c['resource_id'] == option_value.prefixed_id }
      expect(child['resource_type']).to eq('option_value')
      expect(child['translations']['de']['label']).to eq('Klein')
    end
  end

  context 'when the parent param resolves to nothing translatable' do
    it 'has no route for a non-translatable parent' do
      # tax_categories are not in Spree.translatable_resources and the
      # :translatable concern is not mounted on them, so no nested
      # translations route exists — the resource cannot be translated at all.
      expect {
        get :index, params: { tax_category_id: 'tax_1' }, as: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
