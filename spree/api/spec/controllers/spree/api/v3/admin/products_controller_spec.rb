require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }

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
      let!(:other_product) { create(:product, name: 'Unique Widget') }

      it 'filters by name' do
        get :index, params: { q: { name_cont: 'Unique' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['id']).to eq(other_product.prefixed_id)
      end
    end

    # Regression for SPA pickers (`<ResourceMultiAutocomplete>` hydration):
    # the products controller bypasses `ransack_params` for its custom
    # search-provider flow, so prefixed-ID decoding has to live inside
    # `#collection`. Without it `q[id_in][]=prod_…` returns zero rows.
    context 'with q[id_in] using prefixed IDs' do
      let!(:other_product) { create(:product) }
      let!(:third_product) { create(:product) }

      it 'decodes prefixed IDs and returns matching rows' do
        get :index,
            params: { q: { id_in: [product.prefixed_id, third_product.prefixed_id] } },
            as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to contain_exactly(product.prefixed_id, third_product.prefixed_id)
      end

      it 'still accepts raw integer IDs' do
        get :index, params: { q: { id_in: [product.id] } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to eq([product.prefixed_id])
      end

      it 'decodes with q[id_eq] too' do
        get :index, params: { q: { id_eq: other_product.prefixed_id } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to eq([other_product.prefixed_id])
      end
    end

    context 'with q[search] (full-text search)' do
      let!(:matching_product) { create(:product, name: 'Espresso Machine') }
      let!(:non_matching_product) { create(:product, name: 'Garden Hose') }

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
      let!(:second_product) { create(:product, name: 'Alpha Product') }

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
          create(:product, name: 'Cheap').tap do |p|
            p.master.prices.first.update!(amount: 10.0)
          end
        end

        let!(:expensive_product) do
          create(:product, name: 'Expensive').tap do |p|
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
              cost_price: 8.50,
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
                          .and change(Spree::Variant, :count).by(4) # master (auto-created until 6.0 master removal) + 3 variants

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

        # Cost price now lives on the variant, not the master delegate.
        small_variant = created.variants.find_by(sku: 'PREM-TEE-S')
        expect(small_variant.cost_price.to_f).to eq(8.50)

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
        create(:product_with_option_types).tap do |p|
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

    context 'with nested stock_items updates' do
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }
      let!(:variant_to_update) { create(:variant, product: product) }
      let!(:stock_item) do
        variant_to_update.stock_items.find_by(stock_location: stock_location) ||
          create(:stock_item, variant: variant_to_update, stock_location: stock_location, count_on_hand: 5, backorderable: false)
      end

      it 'updates count_on_hand and backorderable per location' do
        patch :update, params: {
          id: product.prefixed_id,
          variants: [
            {
              id: variant_to_update.prefixed_id,
              stock_items: [
                {
                  stock_location_id: stock_location.prefixed_id,
                  count_on_hand: 42,
                  backorderable: true
                }
              ]
            }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        stock_item.reload
        expect(stock_item.count_on_hand).to eq(42)
        expect(stock_item.backorderable).to be true
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

  describe 'POST #bulk_status_update' do
    let!(:second_product) { create(:product, status: 'draft') }
    let(:other_store) { create(:store) }
    let!(:other_store_product) { create(:product, channels: [other_store.default_channel], status: 'active') }

    before { request.headers.merge!(headers) }

    it 'updates status across the listed products and returns the count' do
      post :bulk_status_update, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        status: 'archived'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'status' => 'archived')
      expect(product.reload.status).to eq('archived')
      expect(second_product.reload.status).to eq('archived')
    end

    it 'accepts raw integer IDs alongside prefixed IDs' do
      post :bulk_status_update, params: {
        ids: [product.id.to_s, second_product.prefixed_id],
        status: 'active'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(2)
      expect(product.reload.status).to eq('active')
      expect(second_product.reload.status).to eq('active')
    end

    it 'silently drops products from other stores' do
      post :bulk_status_update, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id],
        status: 'archived'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(product.reload.status).to eq('archived')
      expect(other_store_product.reload.status).to eq('active')
    end

    it 'returns 0 when none of the IDs are reachable' do
      post :bulk_status_update, params: {
        ids: [other_store_product.prefixed_id],
        status: 'archived'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0, 'status' => 'archived')
      expect(other_store_product.reload.status).to eq('active')
    end

    it 'is a no-op when ids is empty' do
      post :bulk_status_update, params: { ids: [], status: 'archived' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0, 'status' => 'archived')
    end

    it 'rejects an omitted ids param with 422' do
      post :bulk_status_update, params: { status: 'archived' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig('error', 'code')).to eq('missing_ids')
    end

    it 'rejects an invalid status with 422' do
      post :bulk_status_update, params: {
        ids: [product.prefixed_id], status: 'bogus'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(product.reload.status).not_to eq('bogus')
    end

    it 'rejects a missing status with 422' do
      post :bulk_status_update, params: { ids: [product.prefixed_id] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Mirrors `spree/admin/spec/controllers/.../products_controller_spec.rb`:
    # asserts the reindex job is enqueued once per affected product.
    it 'reindexes products' do
      allow_any_instance_of(Spree::Product).to receive(:search_indexing_enabled?).and_return(true)

      expect do
        post :bulk_status_update, params: {
          ids: [product.prefixed_id, second_product.prefixed_id], status: 'archived'
        }, as: :json
      end.to have_enqueued_job(Spree::SearchProvider::IndexJob).exactly(2).times
    end

    # Legacy spec sweeps every state machine state and asserts the row flips
    # to `active`. Port verbatim — the destination is `active` here (the API's
    # earlier sweep targeted each status as the *destination*, which only
    # covers the validator). This version covers the actual transition.
    shared_examples 'updates status to active' do |from_status|
      let(:status) { from_status }

      it "updates status to active" do
        product.update!(status: from_status)

        post :bulk_status_update, params: {
          ids: [product.prefixed_id], status: 'active'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.active?).to be(true)
      end
    end

    Spree::Product.state_machine.states.map(&:name).each do |from_status|
      context "when product is in #{from_status} status" do
        it_behaves_like 'updates status to active', from_status
      end
    end
  end

  describe 'POST #bulk_add_to_categories' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:category) { create(:taxon, taxonomy: taxonomy) }
    let(:other_category) { create(:taxon, taxonomy: taxonomy) }
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    it 'attaches every product to every category' do
      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        category_ids: [category.prefixed_id, other_category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'category_count' => 2)
      expect(product.reload.taxons).to include(category, other_category)
      expect(second_product.reload.taxons).to include(category, other_category)
    end

    it 'silently ignores categories from other stores' do
      foreign_taxonomy = create(:taxonomy, store: create(:store))
      foreign_category = create(:taxon, taxonomy: foreign_taxonomy)

      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id],
        category_ids: [category.prefixed_id, foreign_category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['category_count']).to eq(1)
      expect(product.reload.taxons).to include(category)
      expect(product.reload.taxons).not_to include(foreign_category)
    end

    it 'silently drops products from other stores' do
      other_store = create(:store)
      other_store_product = create(:product, channels: [other_store.default_channel])

      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id],
        category_ids: [category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(other_store_product.reload.taxons).to be_empty
    end

    it 'is idempotent — re-adding existing categories is a no-op' do
      product.taxons << category

      expect do
        post :bulk_add_to_categories, params: {
          ids: [product.prefixed_id], category_ids: [category.prefixed_id]
        }, as: :json
      end.not_to change { product.reload.taxons.count }

      expect(response).to have_http_status(:ok)
    end

    it 'is a no-op when category_ids is empty' do
      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id], category_ids: []
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 1, 'category_count' => 0)
      expect(product.reload.taxons).to be_empty
    end

    it 'is a no-op when ids is empty' do
      post :bulk_add_to_categories, params: {
        ids: [], category_ids: [category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0, 'category_count' => 1)
    end

    it 'assigns the product positions on the category list' do
      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        category_ids: [category.prefixed_id]
      }, as: :json

      positions = [
        product.reload.classifications.find_by(taxon: category).position,
        second_product.reload.classifications.find_by(taxon: category).position
      ]
      expect(positions).to contain_exactly(1, 2)
    end

    it 'touches the products' do
      product_old_updated_at = product.reload.updated_at
      second_product_old_updated_at = second_product.reload.updated_at

      Timecop.travel(1.second) do
        post :bulk_add_to_categories, params: {
          ids: [product.prefixed_id, second_product.prefixed_id],
          category_ids: [category.prefixed_id]
        }, as: :json
      end

      expect(product.reload.updated_at).to be > product_old_updated_at
      expect(second_product.reload.updated_at).to be > second_product_old_updated_at
    end

    it 'touches the category' do
      category_old_updated_at = category.reload.updated_at

      Timecop.travel(1.second) do
        post :bulk_add_to_categories, params: {
          ids: [product.prefixed_id],
          category_ids: [category.prefixed_id]
        }, as: :json
      end

      expect(category.reload.updated_at).to be > category_old_updated_at
    end

    # Legacy spec coverage: `bulk_auto_match_taxons` only enqueues jobs for
    # products that are non-deleted and non-archived. Two active products
    # should fire two jobs; archived + soft-deleted siblings are skipped.
    describe 'auto matching taxons' do
      let!(:active_a) { create(:product, status: :active) }
      let!(:active_b) { create(:product, status: :active) }
      let!(:archived) { create(:product, status: :archived) }
      let!(:soft_deleted) { create(:product, status: :draft, deleted_at: Time.current) }

      let(:bulk_ids) do
        [active_a, active_b, archived, soft_deleted].map(&:prefixed_id)
      end

      before { Spree::Taxon.delete_all }

      context 'on a store with automatic taxons' do
        let!(:auto_taxon) { create(:automatic_taxon) }
        let!(:plain_taxon) { create(:taxon) }

        it 'auto matches taxons in bulk only for live active products' do
          expect do
            post :bulk_add_to_categories, params: {
              ids: bulk_ids,
              category_ids: [plain_taxon.prefixed_id]
            }, as: :json
          end.to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
            .on_queue(Spree.queues.taxons)
            .exactly(:twice)

          jobs = Spree::Products::AutoMatchTaxonsJob.queue_adapter.enqueued_jobs.last(2)
          expect(jobs.map { |job| job['arguments'] }).to contain_exactly(
            [active_a.id], [active_b.id]
          )
        end
      end

      context 'on a store without any automatic taxons' do
        let!(:plain_taxon) { create(:taxon) }

        it 'skips auto matching taxons' do
          expect do
            post :bulk_add_to_categories, params: {
              ids: bulk_ids,
              category_ids: [plain_taxon.prefixed_id]
            }, as: :json
          end.not_to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
        end
      end
    end
  end

  describe 'POST #bulk_remove_from_categories' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let(:category) { create(:taxon, taxonomy: taxonomy) }
    let(:other_category) { create(:taxon, taxonomy: taxonomy) }
    let!(:second_product) { create(:product) }

    before do
      request.headers.merge!(headers)
      product.taxons << [category, other_category]
      second_product.taxons << category
    end

    it 'detaches every product from every category' do
      post :bulk_remove_from_categories, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        category_ids: [category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'category_count' => 1)
      expect(product.reload.taxons).not_to include(category)
      expect(product.reload.taxons).to include(other_category)
      expect(second_product.reload.taxons).not_to include(category)
    end

    it 'is a no-op for products not in the category' do
      stray = create(:product)

      post :bulk_remove_from_categories, params: {
        ids: [stray.prefixed_id], category_ids: [category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stray.reload.taxons).to be_empty
    end

    it 'touches the products' do
      product_old_updated_at = product.reload.updated_at
      second_product_old_updated_at = second_product.reload.updated_at

      Timecop.travel(1.second) do
        post :bulk_remove_from_categories, params: {
          ids: [product.prefixed_id, second_product.prefixed_id],
          category_ids: [category.prefixed_id]
        }, as: :json
      end

      expect(product.reload.updated_at).to be > product_old_updated_at
      expect(second_product.reload.updated_at).to be > second_product_old_updated_at
    end

    it 'touches the categories' do
      category_old_updated_at = category.reload.updated_at
      other_category_old_updated_at = other_category.reload.updated_at

      Timecop.travel(1.second) do
        post :bulk_remove_from_categories, params: {
          ids: [product.prefixed_id],
          category_ids: [category.prefixed_id, other_category.prefixed_id]
        }, as: :json
      end

      expect(category.reload.updated_at).to be > category_old_updated_at
      expect(other_category.reload.updated_at).to be > other_category_old_updated_at
    end

    # Legacy spec: after products are detached, surviving classifications
    # collapse their `position` values to a contiguous sequence (1, 2, …).
    it 'reassigns the positions of surviving products on the category list' do
      survivor = create(:product)
      latecomer = create(:product)
      survivor.taxons << category
      latecomer.taxons << category

      post :bulk_remove_from_categories, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        category_ids: [category.prefixed_id]
      }, as: :json

      positions = [
        survivor.reload.classifications.find_by(taxon: category)&.position,
        latecomer.reload.classifications.find_by(taxon: category)&.position
      ].compact.sort

      expect(positions).to eq([1, 2])
    end

    describe 'auto matching taxons' do
      let!(:active_a) { create(:product, status: :active) }
      let!(:active_b) { create(:product, status: :active) }
      let!(:archived) { create(:product, status: :archived) }
      let!(:soft_deleted) { create(:product, status: :draft, deleted_at: Time.current) }

      let(:bulk_ids) do
        [active_a, active_b, archived, soft_deleted].map(&:prefixed_id)
      end

      before { Spree::Taxon.delete_all }

      context 'on a store with automatic taxons' do
        let!(:auto_taxon) { create(:automatic_taxon) }
        let!(:plain_taxon) { create(:taxon) }

        it 'auto matches taxons in bulk only for live active products' do
          expect do
            post :bulk_remove_from_categories, params: {
              ids: bulk_ids,
              category_ids: [plain_taxon.prefixed_id]
            }, as: :json
          end.to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
            .on_queue(Spree.queues.taxons)
            .exactly(:twice)

          jobs = Spree::Products::AutoMatchTaxonsJob.queue_adapter.enqueued_jobs.last(2)
          expect(jobs.map { |job| job['arguments'] }).to contain_exactly(
            [active_a.id], [active_b.id]
          )
        end
      end

      context 'on a store without any automatic taxons' do
        let!(:plain_taxon) { create(:taxon) }

        it 'skips auto matching taxons' do
          expect do
            post :bulk_remove_from_categories, params: {
              ids: bulk_ids,
              category_ids: [plain_taxon.prefixed_id]
            }, as: :json
          end.not_to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
        end
      end
    end
  end

  describe 'POST #bulk_add_tags' do
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    it 'adds the listed tags to every listed product' do
      post :bulk_add_tags, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        tags: %w[summer sale]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'tag_count' => 2)
      expect(product.reload.tag_list).to include('summer', 'sale')
      expect(second_product.reload.tag_list).to include('summer', 'sale')
    end

    it 'is idempotent — re-adding the same tag does not duplicate it' do
      product.tag_list.add('summer')
      product.save!

      post :bulk_add_tags, params: {
        ids: [product.prefixed_id], tags: ['summer']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.tag_list.count { |t| t == 'summer' }).to eq(1)
    end

    it 'strips whitespace from tag names' do
      post :bulk_add_tags, params: {
        ids: [product.prefixed_id], tags: ['  summer  ']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.tag_list).to include('summer')
      expect(product.reload.tag_list).not_to include('  summer  ')
    end

    it 'silently drops products from other stores' do
      other_store = create(:store)
      other_store_product = create(:product, channels: [other_store.default_channel])

      post :bulk_add_tags, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id],
        tags: ['summer']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(other_store_product.reload.tag_list).to be_empty
    end

    it 'is a no-op when tags is empty' do
      post :bulk_add_tags, params: {
        ids: [product.prefixed_id], tags: []
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 1, 'tag_count' => 0)
      expect(product.reload.tag_list).to be_empty
    end

    it 'is a no-op when ids is empty' do
      post :bulk_add_tags, params: { ids: [], tags: ['summer'] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0, 'tag_count' => 1)
    end

    it 'reindexes products' do
      allow_any_instance_of(Spree::Product).to receive(:search_indexing_enabled?).and_return(true)

      expect do
        post :bulk_add_tags, params: {
          ids: [product.prefixed_id, second_product.prefixed_id],
          tags: ['summer']
        }, as: :json
      end.to have_enqueued_job(Spree::SearchProvider::IndexJob).exactly(2).times
    end
  end

  describe 'POST #bulk_remove_tags' do
    let!(:second_product) { create(:product) }

    before do
      request.headers.merge!(headers)
      product.tag_list.add('summer', 'sale')
      product.save!
      second_product.tag_list.add('summer')
      second_product.save!
    end

    it 'removes the listed tags from every listed product' do
      post :bulk_remove_tags, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        tags: ['summer']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'tag_count' => 1)
      expect(product.reload.tag_list).not_to include('summer')
      expect(product.reload.tag_list).to include('sale')
      expect(second_product.reload.tag_list).not_to include('summer')
    end

    it 'is a no-op for products without the tag' do
      stray = create(:product)

      post :bulk_remove_tags, params: {
        ids: [stray.prefixed_id], tags: ['summer']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stray.reload.tag_list).to be_empty
    end

    it 'is a no-op for tags that don\'t exist' do
      post :bulk_remove_tags, params: {
        ids: [product.prefixed_id], tags: ['nonexistent-tag']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.tag_list).to include('summer', 'sale')
    end

    it 'reindexes products' do
      allow_any_instance_of(Spree::Product).to receive(:search_indexing_enabled?).and_return(true)

      expect do
        post :bulk_remove_tags, params: {
          ids: [product.prefixed_id, second_product.prefixed_id],
          tags: ['summer']
        }, as: :json
      end.to have_enqueued_job(Spree::SearchProvider::IndexJob).exactly(2).times
    end
  end

  describe 'DELETE #bulk_destroy' do
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    it 'soft-deletes the listed products' do
      delete :bulk_destroy, params: {
        ids: [product.prefixed_id, second_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2)
      expect(product.reload.deleted_at).not_to be_nil
      expect(second_product.reload.deleted_at).not_to be_nil
    end

    it 'silently drops products from other stores' do
      other_store = create(:store)
      other_store_product = create(:product, channels: [other_store.default_channel])

      delete :bulk_destroy, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(other_store_product.reload.deleted_at).to be_nil
    end

    it 'is a no-op when ids is empty' do
      expect do
        delete :bulk_destroy, params: { ids: [] }, as: :json
      end.not_to change(Spree::Product.where(deleted_at: nil), :count)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0)
    end

    it 'rejects an omitted ids param with 422' do
      delete :bulk_destroy, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig('error', 'code')).to eq('missing_ids')
    end

    it 'returns 0 when the only IDs reference unreachable products' do
      other_store = create(:store)
      other_store_product = create(:product, channels: [other_store.default_channel])

      delete :bulk_destroy, params: {
        ids: [other_store_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0)
      expect(other_store_product.reload.deleted_at).to be_nil
    end
  end
end
