require 'spec_helper'

describe 'Ransackable Attributes' do
  let(:user) { create(:user).tap(&:generate_spree_api_key!) }
  let(:order) { create(:order_with_line_items, user: user) }

  context 'filtering by attributes one association away' do
    it 'does not allow the filtering of variants by order attributes' do
      create_list(:variant, 2)

      get "/api/v1/variants?q[orders_email_start]=#{order.email}", params: { token: user.spree_api_key }

      variants_response = JSON.parse(response.body)
      expect(variants_response['total_count']).to eq(Spree::Variant.eligible.count)
    end
  end

  context 'filtering by attributes two associations away' do
    it 'does not allow the filtering of variants by user attributes' do
      create_list(:variant, 2)

      get "/api/v1/variants?q[orders_user_email_start]=#{order.user.email}", params: { token: user.spree_api_key }

      variants_response = JSON.parse(response.body)
      expect(variants_response['total_count']).to eq(Spree::Variant.eligible.count)
    end
  end

  context 'it maintains desired association behavior' do
    it 'allows filtering of variants product name' do
      product = create(:product, name: 'Fritos')
      variant = create(:variant, product: product)
      other_variant = create(:variant)

      get '/api/v1/variants?q[product_name_or_sku_cont]=fritos', params: { token: user.spree_api_key }

      skus = JSON.parse(response.body)['variants'].map { |var| var['sku'] }
      expect(skus).to include variant.sku
      expect(skus).not_to include other_variant.sku
    end
  end

  context 'filtering by attributes' do
    it 'most attributes are not filterable by default' do
      create(:product, meta_title: 'special product')
      create(:product)

      get '/api/v1/products?q[meta_title_cont]=special', params: { token: user.spree_api_key }

      products_response = JSON.parse(response.body)
      expect(products_response['total_count']).to eq(Spree::Product.count)
    end

    it 'id is filterable by default' do
      product = create(:product)
      other_product = create(:product)

      get "/api/v1/products?q[id_eq]=#{product.id}", params: { token: user.spree_api_key }

      product_names = JSON.parse(response.body)['products'].map { |prod| prod['name'] }
      expect(product_names).to include product.name
      expect(product_names).not_to include other_product.name
    end
  end

  context 'filtering by whitelisted attributes' do
    it 'filtering is supported for whitelisted attributes' do
      product = create(:product, name: 'Fritos')
      other_product = create(:product)

      get '/api/v1/products?q[name_cont]=fritos', params: { token: user.spree_api_key }

      product_names = JSON.parse(response.body)['products'].map { |prod| prod['name'] }
      expect(product_names).to include product.name
      expect(product_names).not_to include other_product.name
    end
  end
end
