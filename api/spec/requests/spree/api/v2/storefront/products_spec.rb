require 'spec_helper'

describe 'API V2 Storefront Products Spec', type: :request do
  let(:product) { create(:product) }

  describe 'products#show' do
    context 'with non-existing product' do
      before { get '/api/v2/storefront/products/example' }

      it 'returns a propert HTTP status' do
        expect(response.status).to eq 404
      end
    end

    context 'with existing product' do
      before { get "/api/v2/storefront/products/#{product.slug}" }

      it 'returns a proper HTTP status' do
        expect(response.status).to eq 200
      end

      it 'returns a valid JSON response' do
        expect(json_response['data']).to have_id(product.id.to_s)

        expect(json_response['data']).to have_type('product')

        expect(json_response['data']).to have_attribute(:name).with_value(product.name)
        expect(json_response['data']).to have_attribute(:description).with_value(product.description)
        expect(json_response['data']).to have_attribute(:price).with_value(product.price.to_s)
        expect(json_response['data']).to have_attribute(:currency).with_value(product.currency)
        expect(json_response['data']).to have_attribute(:display_price).with_value(product.display_price.to_s)
        expect(json_response['data']).to have_attribute(:available_on).with_value(product.available_on.as_json)
        expect(json_response['data']).to have_attribute(:slug).with_value(product.slug)
        expect(json_response['data']).to have_attribute(:meta_description).with_value(product.meta_description)
        expect(json_response['data']).to have_attribute(:meta_keywords).with_value(product.meta_keywords)
        expect(json_response['data']).to have_attribute(:updated_at).with_value(product.updated_at.as_json)
        expect(json_response['data']).to have_attribute(:purchasable).with_value(product.purchasable?)
        expect(json_response['data']).to have_attribute(:in_stock).with_value(product.in_stock?)
        expect(json_response['data']).to have_attribute(:backorderable).with_value(product.backorderable?)

        expect(json_response['data']).to have_relationships(
          :variants, :option_types, :product_properties, :default_variant
        )
      end
    end
  end
end
