require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TranslatableResourcesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists every translatable resource and its fields' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      resources = json_response['data']
      product = resources.find { |r| r['resource_type'] == 'product' }
      expect(product).to be_present

      field_keys = product['fields'].map { |f| f['key'] }
      expect(field_keys).to include('name', 'description', 'slug')

      description_field = product['fields'].find { |f| f['key'] == 'description' }
      expect(description_field['type']).to eq('html')
      # slug is a plain string field — only model-declared rich text is 'html'
      expect(product['fields'].find { |f| f['key'] == 'slug' }['type']).to eq('string')
      expect(product['fields'].find { |f| f['key'] == 'name' }['type']).to eq('string')
    end

    it 'flags which resources have a dedicated read route' do
      get :index, params: {}, as: :json

      resources = json_response['data'].index_by { |r| r['resource_type'] }
      expect(resources['product']['readable']).to be(true)
      expect(resources['category']['readable']).to be(true)
      # Writable via batch + readable inline as children, but no standalone route.
      expect(resources['option_value']['readable']).to be(false)
    end
  end
end
