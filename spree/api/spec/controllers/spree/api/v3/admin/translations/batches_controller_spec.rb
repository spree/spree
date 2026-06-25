require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Translations::BatchesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }
  let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }
  let!(:option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type) }

  before do
    configure_supported_locales(store, %w[en de fr])
    request.headers.merge!(headers)
  end

  describe 'POST #create' do
    it 'upserts translations across multiple resource types in one request' do
      post :create, params: {
        translations: [
          { resource_type: 'product',      resource_id: product.prefixed_id,      values: { de: { name: 'Espressomaschine' } } },
          { resource_type: 'option_type',  resource_id: option_type.prefixed_id,  values: { de: { label: 'Größe' } } },
          { resource_type: 'option_value', resource_id: option_value.prefixed_id, values: { de: { label: 'Klein' } } }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(3)

      Mobility.with_locale(:de) do
        expect(product.reload.name).to eq('Espressomaschine')
        expect(option_type.reload.presentation).to eq('Größe')
        expect(option_value.reload.presentation).to eq('Klein')
      end
    end

    it 'is atomic: one invalid entry rolls back the whole batch' do
      post :create, params: {
        translations: [
          { resource_type: 'option_type',  resource_id: option_type.prefixed_id,  values: { de: { label: 'Größe' } } },
          # unsupported locale → 422, must roll back the option_type write above
          { resource_type: 'option_value', resource_id: option_value.prefixed_id, values: { es: { label: 'Pequeño' } } }
        ]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      Mobility.with_locale(:de) { expect(option_type.reload.presentation).to eq('Size') }
    end

    it 'reports the offending entry index for an unknown resource type' do
      post :create, params: {
        translations: [
          { resource_type: 'product',  resource_id: product.prefixed_id, values: { de: { name: 'X' } } },
          { resource_type: 'unicorn',  resource_id: 'u_1',               values: { de: { name: 'Y' } } }
        ]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['translations']).to have_key('1')
    end

    it 'returns 404-equivalent 422 for a resource missing in the current store' do
      post :create, params: {
        translations: [
          { resource_type: 'product', resource_id: 'prod_NotReal', values: { de: { name: 'X' } } }
        ]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an empty batch' do
      post :create, params: { translations: [] }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
