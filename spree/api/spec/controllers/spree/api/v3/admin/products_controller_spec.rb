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
    subject { post :create, params: product_params, as: :json }

    before { request.headers.merge!(headers) }

    let(:tax_category) { create(:tax_category) }
    let(:shipping_category) { create(:shipping_category) }
    let(:product_params) do
      {
        name: 'New Product',
        price: 19.99,
        shipping_category_id: shipping_category.id
      }
    end

    it 'creates a product' do
      expect { subject }.to change(Spree::Product, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Product')
    end

    context 'with nested variants, prices, tags, and taxon_ids' do
      let(:taxonomy) { create(:taxonomy, store: store) }
      let(:taxon) { create(:taxon, taxonomy: taxonomy) }
      let(:product_params) do
        {
          name: 'Test product',
          price: 10.99,
          shipping_category_id: shipping_category.id,
          tax_category_id: tax_category.prefixed_id,
          taxon_ids: [taxon.prefixed_id],
          tags: ['eco', 'best-seller'],
          variants: [
            {
              option_type: 'size',
              option_value: 'small',
              sku: 'TEST-SM',
              total_on_hand: 10,
              track_inventory: true,
              weight: 0.5,
              prices: [
                { currency: 'USD', amount: 10.99 },
                { currency: 'EUR', amount: 9.99 }
              ]
            }
          ]
        }
      end

      it 'creates product with all nested data' do
        expect { subject }.to change(Spree::Product, :count).by(1)
                          .and change(Spree::Variant, :count).by(2) # master + variant

        expect(response).to have_http_status(:created)
        expect(json_response['name']).to eq('Test product')

        created_product = Spree::Product.find_by(name: 'Test product')
        expect(created_product.tag_list).to match_array(['eco', 'best-seller'])
        expect(created_product.taxons).to include(taxon)
        expect(created_product.tax_category).to eq(tax_category)

        variant = created_product.variants.first
        expect(variant.sku).to eq('TEST-SM')
        expect(variant.option_values.first.presentation).to eq('small')
        expect(variant.prices.count).to be >= 2
        expect(variant.prices.find_by(currency: 'EUR').amount.to_f).to eq(9.99)
      end
    end

    context 'with invalid params' do
      let(:product_params) { { name: '' } }

      it 'returns validation errors' do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']).to have_key('details')
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { id: product.prefixed_id, name: 'Updated Name' }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the product' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Name')
      expect(product.reload.name).to eq('Updated Name')
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
