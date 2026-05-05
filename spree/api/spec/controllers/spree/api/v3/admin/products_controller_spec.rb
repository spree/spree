require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, stores: [store]) }

  describe 'GET #index' do
    subject { get :index, params: {}, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns products list' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['id']).to eq(product.prefixed_id)
      expect(json_response['data'].first['name']).to eq(product.name)
    end

    it 'includes admin-only fields' do
      subject

      data = json_response['data'].first
      expect(data).to have_key('status')
    end

    it 'returns pagination metadata' do
      subject

      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    context 'with ransack filtering' do
      let!(:other_product) { create(:product, name: 'Unique Widget', stores: [store]) }

      it 'filters by name' do
        get :index, params: { q: { name_cont: 'Unique' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['id']).to eq(other_product.prefixed_id)
      end
    end

    context 'with q[search] (full-text search)' do
      let!(:matching_product) { create(:product, name: 'Espresso Machine', stores: [store]) }
      let!(:non_matching_product) { create(:product, name: 'Garden Hose', stores: [store]) }

      it 'matches by product name' do
        get :index, params: { q: { search: 'Espresso' } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(matching_product.prefixed_id)
        expect(ids).not_to include(non_matching_product.prefixed_id)
      end

      it 'matches by master variant SKU' do
        matching_product.master.update!(sku: 'ESPRESSO-PRO-2026')

        get :index, params: { q: { search: 'ESPRESSO-PRO' } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(matching_product.prefixed_id)
        expect(ids).not_to include(non_matching_product.prefixed_id)
      end

      it 'returns no results when nothing matches' do
        get :index, params: { q: { search: 'xqzwkj-no-such-product' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_empty
      end
    end

    context 'with sorting' do
      let!(:second_product) { create(:product, name: 'Alpha Product', stores: [store]) }

      it 'sorts by name ascending' do
        get :index, params: { sort: 'name' }, as: :json

        names = json_response['data'].map { |p| p['name'] }
        expect(names).to eq(names.sort)
      end

      it 'sorts by name descending' do
        get :index, params: { sort: '-name' }, as: :json

        names = json_response['data'].map { |p| p['name'] }
        expect(names).to eq(names.sort.reverse)
      end

      context 'by price' do
        let!(:cheap_product) do
          create(:product, stores: [store], name: 'Cheap').tap do |p|
            p.master.prices.first.update!(amount: 10.0)
          end
        end

        let!(:expensive_product) do
          create(:product, stores: [store], name: 'Expensive').tap do |p|
            p.master.prices.first.update!(amount: 100.0)
          end
        end

        it 'sorts by price ascending' do
          get :index, params: { sort: 'price' }, as: :json

          expect(response).to have_http_status(:ok)
          prices = json_response['data'].map { |p| p['price']['amount'].to_f }
          expect(prices).to eq(prices.sort)
        end

        it 'sorts by price descending' do
          get :index, params: { sort: '-price' }, as: :json

          expect(response).to have_http_status(:ok)
          prices = json_response['data'].map { |p| p['price']['amount'].to_f }
          expect(prices).to eq(prices.sort.reverse)
        end

        it 'paginates correctly when sorting by price' do
          get :index, params: { sort: 'price', page: 1, limit: 1 }, as: :json

          expect(response).to have_http_status(:ok)
          expect(json_response['data'].size).to eq(1)
          expect(json_response['meta']['pages']).to be >= 2
        end
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns 401 unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: product.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns the product' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(product.prefixed_id)
      expect(json_response['name']).to eq(product.name)
      expect(json_response['slug']).to eq(product.slug)
    end

    it 'includes admin-only fields' do
      subject

      expect(json_response).to have_key('status')
    end

    context 'with expand' do
      it 'expands variants' do
        get :show, params: { id: product.prefixed_id, expand: 'variants' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('variants')
      end
    end

    context 'with non-existent product' do
      it 'returns 404' do
        get :show, params: { id: 'prod_nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    before { request.headers.merge!(headers) }

    let(:tax_category) { create(:tax_category) }
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:category1) { create(:taxon, taxonomy: taxonomy) }
    let(:category2) { create(:taxon, taxonomy: taxonomy) }

    it 'creates a minimal product' do
      expect {
        post :create, params: { name: 'Simple Product', price: 19.99 }, as: :json
      }.to change(Spree::Product, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Simple Product')
    end

    context 'with full payload: multiple variants, multi-currency prices, categories, tags' do
      let(:product_params) do
        {
          name: 'Premium T-Shirt',
          description: 'A premium cotton t-shirt',
          status: 'draft',
          cost_price: 8.50,
          sku: 'PREM-TEE',
          tax_category_id: tax_category.prefixed_id,
          category_ids: [category1.prefixed_id, category2.prefixed_id],
          tags: ['premium', 'cotton', 'summer'],
          slug: 'premium-t-shirt',
          meta_title: 'Premium T-Shirt',
          meta_description: 'Shop our premium cotton t-shirt',
          variants: [
            {
              sku: 'PREM-TEE-S',
              options: [{ name: 'size', value: 'Small' }],
              weight: 0.2,
              width: 30,
              height: 40,
              depth: 2,
              weight_unit: 'kg',
              dimensions_unit: 'cm',
              track_inventory: true,
              prices: [
                { currency: 'USD', amount: 29.99, compare_at_amount: 39.99 },
                { currency: 'EUR', amount: 27.99 },
                { currency: 'GBP', amount: 24.99 }
              ]
            },
            {
              sku: 'PREM-TEE-M',
              options: [{ name: 'size', value: 'Medium' }],
              weight: 0.22,
              track_inventory: true,
              prices: [
                { currency: 'USD', amount: 29.99 },
                { currency: 'EUR', amount: 27.99 },
                { currency: 'GBP', amount: 24.99 }
              ]
            },
            {
              sku: 'PREM-TEE-L',
              options: [{ name: 'size', value: 'Large' }],
              weight: 0.25,
              track_inventory: true,
              prices: [
                { currency: 'USD', amount: 31.99 },
                { currency: 'EUR', amount: 29.99 },
                { currency: 'GBP', amount: 26.99 }
              ]
            }
          ]
        }
      end

      it 'creates product with all nested data' do
        expect {
          post :create, params: product_params, as: :json
        }.to change(Spree::Product, :count).by(1)
                          .and change(Spree::Variant, :count).by(4) # master + 3 variants

        expect(response).to have_http_status(:created)

        created = Spree::Product.find_by(name: 'Premium T-Shirt')
        expect(created).to be_present

        # Product attributes
        expect(created.description).to include('premium cotton')
        expect(created.status).to eq('draft')
        expect(created.slug).to eq('premium-t-shirt')
        expect(created.meta_title).to eq('Premium T-Shirt')
        expect(created.tax_category).to eq(tax_category)
        expect(created.tag_list).to match_array(['premium', 'cotton', 'summer'])
        expect(created.taxons).to match_array([category1, category2])

        # Master variant
        master = created.master
        expect(master.sku).to eq('PREM-TEE')
        expect(master.cost_price.to_f).to eq(8.50)

        # Variants
        expect(created.variants.count).to eq(3)

        small = created.variants.find_by(sku: 'PREM-TEE-S')
        expect(small).to be_present
        expect(small.weight.to_f).to eq(0.2)
        expect(small.width.to_f).to eq(30.0)
        expect(small.height.to_f).to eq(40.0)
        expect(small.depth.to_f).to eq(2.0)
        expect(small.option_values.first.presentation).to eq('Small')
        expect(small.option_values.first.option_type.name).to eq('size')

        # Multi-currency prices
        expect(small.prices.count).to be >= 3
        expect(small.prices.find_by(currency: 'USD').amount.to_f).to eq(29.99)
        expect(small.prices.find_by(currency: 'USD').compare_at_amount.to_f).to eq(39.99)
        expect(small.prices.find_by(currency: 'EUR').amount.to_f).to eq(27.99)
        expect(small.prices.find_by(currency: 'GBP').amount.to_f).to eq(24.99)

        medium = created.variants.find_by(sku: 'PREM-TEE-M')
        expect(medium).to be_present

        large = created.variants.find_by(sku: 'PREM-TEE-L')
        expect(large).to be_present
        expect(large.prices.find_by(currency: 'USD').amount.to_f).to eq(31.99)
        expect(large.prices.find_by(currency: 'GBP').amount.to_f).to eq(26.99)
      end
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post :create, params: { name: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']).to have_key('details')
      end
    end
  end

  describe 'PATCH #update' do
    before { request.headers.merge!(headers) }

    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:category1) { create(:taxon, taxonomy: taxonomy) }
    let(:category2) { create(:taxon, taxonomy: taxonomy) }
    let(:tax_category) { create(:tax_category) }

    it 'updates basic product attributes' do
      patch :update, params: { id: product.prefixed_id, name: 'Updated Name' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Name')
      expect(product.reload.name).to eq('Updated Name')
    end

    context 'with full payload: name, description, status, categories, tags, SEO, variants with multi-currency prices' do
      let!(:product_to_update) do
        create(:product_with_option_types, stores: [store]).tap do |p|
          p.master.update!(sku: 'OLD-SKU')
        end
      end

      let(:update_params) do
        {
          id: product_to_update.prefixed_id,
          name: 'Updated Premium Shirt',
          description: 'Updated description for the premium shirt',
          status: 'active',
          slug: 'updated-premium-shirt',
          meta_title: 'Updated Premium Shirt | Shop',
          meta_description: 'Buy the updated premium shirt',
          category_ids: [category1.prefixed_id, category2.prefixed_id],
          tags: ['updated', 'premium', 'new-arrival'],
          tax_category_id: tax_category.prefixed_id,
          variants: [
            {
              sku: 'UPD-SHIRT-S',
              options: [{ name: 'size', value: 'Small' }],
              weight: 0.3,
              track_inventory: true,
              prices: [
                { currency: 'USD', amount: 34.99, compare_at_amount: 49.99 },
                { currency: 'EUR', amount: 31.99 },
                { currency: 'GBP', amount: 28.99 }
              ]
            },
            {
              sku: 'UPD-SHIRT-XL',
              options: [{ name: 'size', value: 'XL' }],
              weight: 0.4,
              track_inventory: true,
              prices: [
                { currency: 'USD', amount: 36.99 },
                { currency: 'EUR', amount: 33.99 },
                { currency: 'GBP', amount: 30.99 }
              ]
            }
          ]
        }
      end

      it 'updates product with all nested data' do
        patch :update, params: update_params, as: :json

        expect(response).to have_http_status(:ok)

        updated = product_to_update.reload
        expect(updated.name).to eq('Updated Premium Shirt')
        expect(updated.status).to eq('active')
        expect(updated.slug).to eq('updated-premium-shirt')
        expect(updated.meta_title).to eq('Updated Premium Shirt | Shop')
        expect(updated.tax_category).to eq(tax_category)
        expect(updated.tag_list).to match_array(['updated', 'premium', 'new-arrival'])
        expect(updated.taxons).to match_array([category1, category2])

        # Variants created
        small = updated.variants.find_by(sku: 'UPD-SHIRT-S')
        expect(small).to be_present
        expect(small.weight.to_f).to eq(0.3)
        expect(small.option_values.first.presentation).to eq('Small')

        # Multi-currency prices on small variant
        expect(small.prices.find_by(currency: 'USD').amount.to_f).to eq(34.99)
        expect(small.prices.find_by(currency: 'USD').compare_at_amount.to_f).to eq(49.99)
        expect(small.prices.find_by(currency: 'EUR').amount.to_f).to eq(31.99)
        expect(small.prices.find_by(currency: 'GBP').amount.to_f).to eq(28.99)

        xl = updated.variants.find_by(sku: 'UPD-SHIRT-XL')
        expect(xl).to be_present
        expect(xl.prices.find_by(currency: 'GBP').amount.to_f).to eq(30.99)
      end
    end

    context 'with category_ids' do
      it 'assigns categories via prefixed IDs' do
        patch :update, params: {
          id: product.prefixed_id,
          category_ids: [category1.prefixed_id, category2.prefixed_id]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.taxons).to match_array([category1, category2])
      end

      it 'replaces existing categories' do
        product.taxons << category1
        patch :update, params: {
          id: product.prefixed_id,
          category_ids: [category2.prefixed_id]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.taxons.where(taxonomy: taxonomy)).to eq([category2])
      end

      it 'clears categories when empty array' do
        product.taxons << category1
        patch :update, params: {
          id: product.prefixed_id,
          category_ids: []
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.taxons.where(taxonomy: taxonomy)).to be_empty
      end
    end

    context 'with tags' do
      it 'updates product tags' do
        patch :update, params: { id: product.prefixed_id, tags: ['new-tag', 'sale'] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.tag_list).to match_array(['new-tag', 'sale'])
      end
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        patch :update, params: { id: product.prefixed_id, name: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: product.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'soft-deletes the product' do
      subject

      expect(response).to have_http_status(:no_content)
      expect(product.reload.deleted_at).not_to be_nil
    end
  end

  describe 'POST #clone' do
    subject { post :clone, params: { id: product.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'clones the product' do
      expect { subject }.to change(Spree::Product, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to include('COPY OF')
    end
  end
end
