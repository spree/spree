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
      expect(product['fields'].find { |f| f['key'] == 'slug' }['type']).to eq('slug')
      expect(product['fields'].find { |f| f['key'] == 'name' }['type']).to eq('string')
    end
  end
end
