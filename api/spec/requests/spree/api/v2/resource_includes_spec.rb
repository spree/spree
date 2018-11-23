require 'spec_helper'
require 'shared_examples/api_v2/base'

describe 'API v2 JSON API Resource Includes Spec', type: :request do
  let!(:products) { create_list(:product, 5) }
  let!(:product) { create(:product) }
  let!(:product_option_type) { create(:product_option_type, product: product) }
  let(:default_variant) { product.master }

  shared_examples 'default resources' do
    it 'are returned' do
      expect(json_response['included']).to be_present
      expect(json_response['included']).to include(have_type('variant').and have_id(default_variant.id.to_s))
      expect(json_response['included']).to include(have_type('option_type').and have_id(product.option_types.first.id.to_s))
    end
  end

  shared_examples 'requested resources' do
    it 'are returned' do
      expect(json_response['included']).to be_present
      expect(json_response['included']).to include(have_type('variant').and have_id(default_variant.id.to_s))
      expect(json_response['included']).not_to include(have_type('option_type'))
    end
  end

  context 'singular resource' do
    context 'without include param' do
      before { get "/api/v2/storefront/products/#{product.id}" }

      it_behaves_like 'default resources'
    end

    context 'with include param' do
      context 'empty param' do
        before { get "/api/v2/storefront/products/#{product.id}?include=" }

        it_behaves_like 'default resources'
      end

      context 'present param' do
        before { get "/api/v2/storefront/products/#{product.id}?include=default_variant" }

        it_behaves_like 'requested resources'
      end
    end
  end

  context 'collections' do
    context 'without include param' do
      before { get '/api/v2/storefront/products' }

      it_behaves_like 'default resources'
    end

    context 'with include param' do
      context 'empty param' do
        before { get '/api/v2/storefront/products?include=' }

        it_behaves_like 'default resources'
      end

      context 'present param' do
        before { get '/api/v2/storefront/products?include=default_variant' }

        it_behaves_like 'requested resources'
      end
    end
  end
end
