require 'spec_helper'

describe 'API v2 JSON API Sparse Fields Spec', type: :request do
  let!(:product) { create(:product_with_option_types) }

  shared_examples 'no sparse fields requested' do
    it 'returns all attributes' do
      expect(json_response['data']['attributes']).to be_present
      expect(json_response['data']['attributes'].count > 3).to eq true
    end
  end

  context 'without fields param' do
    before { get "/api/v2/storefront/products/#{product.id}" }

    it_behaves_like 'no sparse fields requested'
  end

  context 'with empty fields param' do
    before { get "/api/v2/storefront/products/#{product.id}?fields=" }

    it_behaves_like 'no sparse fields requested'
  end

  context 'with proper fields param' do
    before { get "/api/v2/storefront/products/#{product.id}?fields[product]=name,price,currency" }

    it 'filters resource attributes' do
      expect(json_response['data']['attributes']).to be_present
      expect(json_response['data']['attributes'].keys).to contain_exactly('name', 'price', 'currency')
    end
  end

  context 'with included resources' do
    before { get "/api/v2/storefront/products/#{product.id}?include=option_types&fields[option_type]=name,presentation" }

    it 'filters resource attributes' do
      expect(json_response['included']).to be_present
      expect(json_response['included']).to include(have_type('option_type'))
      expect(json_response['included'].first['attributes'].keys).to contain_exactly('name', 'presentation')
    end
  end
end
