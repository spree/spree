require 'spec_helper'

describe 'API v2 JSON API Resource Includes Spec', type: :request do
  let!(:products) { create_list(:product, 5) }
  let!(:product) { create(:product) }
  let!(:product_option_type) { create(:product_option_type, product: product) }
  let!(:option_value) { create(:option_value, option_type: product_option_type.option_type) }
  let(:default_variant) { product.master }

  shared_examples 'requested resources' do
    it 'are returned' do
      expect(json_response['included']).to be_present
      expect(json_response['included']).to include(have_type('variant').and have_id(default_variant.id.to_s))
      expect(json_response['included']).not_to include(have_type('option_type'))
    end
  end

  shared_examples 'nested requested resources' do
    it 'are returned' do
      expect(json_response['included']).to be_present
      expect(json_response['included']).not_to include(have_type('variant').and have_id(default_variant.id.to_s))
      expect(json_response['included']).to include(have_type('option_type'))
      expect(json_response['included']).to include(have_type('option_value'))
    end
  end

  shared_examples 'requested no resources' do
    it 'nothing is returned' do
      expect(json_response['included']).not_to be_present
    end
  end

  context 'singular resource' do
    context 'without include param' do
      before { get "/api/v2/storefront/products/#{product.id}" }

      it_behaves_like 'requested no resources'
    end

    context 'with include param' do
      context 'empty param' do
        before { get "/api/v2/storefront/products/#{product.id}?include=" }

        it_behaves_like 'requested no resources'
      end

      context 'with non-existing relation requested' do
        before { get "/api/v2/storefront/products/#{product.id}?include=does_not_exist" }

        it_behaves_like 'returns 400 HTTP status'
      end

      context 'present param' do
        context 'without nested resources' do
          before { get "/api/v2/storefront/products/#{product.id}?include=default_variant" }

          it_behaves_like 'requested resources'
        end

        context 'with nested resources' do
          before { get "/api/v2/storefront/products/#{product.id}?include=option_types,option_types.option_values" }

          it_behaves_like 'nested requested resources'
        end
      end
    end
  end

  context 'collections' do
    context 'without include param' do
      before { get '/api/v2/storefront/products' }

      it_behaves_like 'requested no resources'
    end

    context 'with include param' do
      context 'empty param' do
        before { get '/api/v2/storefront/products?include=' }

        it_behaves_like 'requested no resources'
      end

      context 'present param' do
        context 'without nested resources' do
          before { get '/api/v2/storefront/products?include=default_variant' }

          it_behaves_like 'requested resources'
        end

        context 'with nested resources' do
          before { get '/api/v2/storefront/products?include=option_types,option_types.option_values' }

          it_behaves_like 'nested requested resources'
        end
      end
    end
  end
end
