require 'spec_helper'

RSpec.describe 'API V2 Storefront Variants Spec', type: :request  do
  describe 'GET /api/v2/storefront/products/:id/variants' do
    let!(:color) { create(:option_type, :color) }
    let!(:green_color) { create(:option_value, option_type: color, name: 'green', presentation: 'Green') }
    let!(:white_color) { create(:option_value, option_type: color, name: 'white', presentation: 'White') }

    let!(:size) { Spree::OptionType.find_by(name: 'size') || create(:option_type, :size) }
    let!(:s_size) { create(:option_value, option_type: size, name: 's', presentation: 'S') }
    let!(:m_size) { create(:option_value, option_type: size, name: 'm', presentation: 'M') }

    let!(:product) { create(:product_in_stock, option_types: [color, size]) }

    let!(:variant_1) { create(:variant, product: product, option_values: [green_color, s_size]) }
    let!(:variant_2) { create(:variant, product: product, option_values: [green_color, m_size]) }
    let!(:variant_3) { create(:variant, product: product, option_values: [white_color, s_size]) }
    let!(:variant_4) { create(:variant, product: product, option_values: [white_color, m_size]) }

    let!(:other_product) { create(:product_in_stock, option_types: [color]) }

    let!(:other_variant_1) { create(:variant, product: other_product, option_values: [green_color]) }
    let!(:other_variant_2) { create(:variant, product: other_product, option_values: [white_color]) }

    context 'with no params' do
      before { get "/api/v2/storefront/products/#{product.id}/variants" }

      it 'returns all product variants including master' do
        expect(json_response['data'].count).to eq(5)

        expect(json_response['data']).to include(have_type('variant').and(have_id(product.master.id.to_s)))
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_1.id.to_s)))
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_2.id.to_s)))
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_3.id.to_s)))
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_4.id.to_s)))
      end
    end

    context 'with specified option name and value' do
      before { get "/api/v2/storefront/products/#{product.id}/variants?filter[options][color]=white" }

      it 'returns product variants with the specified option' do
        expect(json_response['data'].count).to eq(2)

        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_3.id.to_s)))
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_4.id.to_s)))
      end
    end

    context 'with multiple options' do
      before { get "/api/v2/storefront/products/#{product.id}/variants?filter[options][color]=white&filter[options][size]=m" }

      it 'returns product variants with the specified options' do
        expect(json_response['data'].count).to eq(1)
        expect(json_response['data']).to include(have_type('variant').and(have_id(variant_4.id.to_s)))
      end
    end
  end
end
