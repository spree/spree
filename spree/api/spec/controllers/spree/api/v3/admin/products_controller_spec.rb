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

      context 'filtering by channel via channels_id_in' do
        let(:pos_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }
        let!(:pos_product) { create(:product, store: store) }
        let!(:default_channel_product) { create(:product, store: store) }

        before do
          # Override the auto-publish on the default channel so each product is
          # on exactly one channel — clean assertion target.
          pos_product.product_publications.destroy_all
          default_channel_product.product_publications.destroy_all
          pos_channel.add_products([pos_product.id])
          store.default_channel.add_products([default_channel_product.id])
        end

        it 'returns only products published on the requested channel' do
          get :index, params: { q: { channels_id_in: [pos_channel.id] } }, as: :json

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to include(pos_product.prefixed_id)
          expect(ids).not_to include(default_channel_product.prefixed_id)
        end
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

      it 'matches by default variant SKU' do
        matching_product.default_variant.update!(sku: 'ESPRESSO-PRO-2026')

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
            p.default_variant.prices.first.update!(amount: 10.0)
          end
        end

        let!(:expensive_product) do
          create(:product, name: 'Expensive').tap do |p|
            p.default_variant.prices.first.update!(amount: 100.0)
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
                          .and change(Spree::Variant, :count).by(3) # 3 option variants

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

        # Cost price now lives on the variant, not delegated from the product.
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

      # Variants are created in an after_create callback, so the response must
      # reflect them without a reload. Asserts on the RESPONSE BODY (not a DB
      # re-read) — the only assertion that guards the stale-response bug.
      it 'returns fresh variant_count and price in the create response' do
        post :create, params: product_params, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['variant_count']).to eq(3)
        expect(json_response['price']).to be_present
        expect(json_response['price']['amount'].to_f).to eq(29.99)
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

    context 'with inline custom fields' do
      let!(:material_definition) do
        create(:metafield_definition,
               resource_type: 'Spree::Product',
               namespace: 'product',
               key: 'material',
               metafield_type: 'Spree::Metafields::ShortText')
      end
      let!(:waterproof_definition) do
        create(:metafield_definition,
               resource_type: 'Spree::Product',
               namespace: 'product',
               key: 'waterproof',
               metafield_type: 'Spree::Metafields::Boolean')
      end

      it 'persists custom_fields inline on create' do
        expect {
          post :create, params: {
            name: 'Custom Fields Product',
            custom_fields: [
              { custom_field_definition_id: material_definition.prefixed_id, value: 'Cotton' },
              { custom_field_definition_id: waterproof_definition.prefixed_id, value: false }
            ]
          }, as: :json
        }.to change(Spree::Product, :count).by(1)
                                            .and change(Spree::Metafield, :count).by(2)

        expect(response).to have_http_status(:created)

        created = Spree::Product.find_by(name: 'Custom Fields Product')
        material = created.metafields.find_by(metafield_definition: material_definition)
        waterproof = created.metafields.find_by(metafield_definition: waterproof_definition)
        expect(material.value).to eq('Cotton')
        # Boolean metafields store the value as a serialized string ("f"/"t"
        # on SQLite). The dashboard reads them back via the API which casts.
        expect(waterproof.value).to be_in(['false', 'f', false])
      end

      it 'skips entries with a blank value on create' do
        expect {
          post :create, params: {
            name: 'Half-Filled Custom Fields',
            custom_fields: [
              { custom_field_definition_id: material_definition.prefixed_id, value: 'Cotton' },
              { custom_field_definition_id: waterproof_definition.prefixed_id, value: '' }
            ]
          }, as: :json
        }.to change(Spree::Product, :count).by(1)
                                            .and change(Spree::Metafield, :count).by(1)

        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'Half-Filled Custom Fields')
        expect(created.metafields.find_by(metafield_definition: material_definition).value).to eq('Cotton')
        expect(created.metafields.find_by(metafield_definition: waterproof_definition)).to be_nil
      end

      it 'skips entries with a missing custom_field_definition_id' do
        expect {
          post :create, params: {
            name: 'Custom Fields No Def',
            custom_fields: [
              { value: 'Orphan value' },
              { custom_field_definition_id: material_definition.prefixed_id, value: 'Silk' }
            ]
          }, as: :json
        }.to change(Spree::Product, :count).by(1)
                                            .and change(Spree::Metafield, :count).by(1)

        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'Custom Fields No Def')
        expect(created.metafields.find_by(metafield_definition: material_definition).value).to eq('Silk')
      end

      it 'persists a Hash value for a JSON-typed custom field' do
        json_definition = create(
          :metafield_definition,
          resource_type: 'Spree::Product',
          namespace: 'product',
          key: 'spec',
          metafield_type: 'Spree::Metafields::Json'
        )

        post :create, params: {
          name: 'JSON Custom Field Product',
          custom_fields: [
            { custom_field_definition_id: json_definition.prefixed_id, value: { foo: 'bar', n: 1 } }
          ]
        }, as: :json

        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'JSON Custom Field Product')
        mf = created.metafields.find_by(metafield_definition: json_definition)
        expect(mf).to be_present
        # Json metafields store the hash as serialized JSON. We only care
        # that the content survived strong-params (would be nil if dropped)
        # — the precise on-disk representation depends on the type.
        parsed = mf.value.is_a?(Hash) ? mf.value : JSON.parse(mf.value.to_s)
        expect(parsed).to include('foo' => 'bar')
      end

      it 'creates a simple product with media + variant stock items in one POST (regression for dashboard payload)' do
        # Mirrors the exact wire shape the dashboard ships from
        # `new.tsx` for a simple product with media + inventory:
        # - status, channels, custom_fields, media, variants[] with empty
        #   options + stock_items routed to the default variant via apply_variants.
        blob1 = ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'one.jpg',
          content_type: 'image/jpeg'
        )
        blob2 = ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'two.jpg',
          content_type: 'image/jpeg'
        )
        location = create(:stock_location)

        expect {
          post :create, params: {
            name: 'test product',
            status: 'active',
            media: [
              { signed_id: blob1.signed_id, alt: 'one', position: 1 },
              { signed_id: blob2.signed_id, alt: 'two', position: 2 }
            ],
            variants: [
              {
                position: 1, options: [], sku: '', weight: 0, track_inventory: true,
                stock_items: [
                  { stock_location_id: location.prefixed_id, count_on_hand: 10, backorderable: false }
                ]
              }
            ]
          }, as: :json
        }.to change(Spree::Product, :count).by(1)
                                           .and change(Spree::Asset, :count).by(2)

        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'test product')
        expect(created.media.count).to eq(2)
        expect(created.default_variant.stock_items.find_by(stock_location: location).count_on_hand).to eq(10)
        # Simple product has exactly one variant — the default variant.
        expect(created.variants.count).to eq(1)
      end

      it 'returns 422 with field-level details for an unknown custom_field_definition_id' do
        expect {
          post :create, params: {
            name: 'Bad CF Product',
            custom_fields: [
              { custom_field_definition_id: 'cfdef_garbage', value: 'X' }
            ]
          }, as: :json
        }.not_to change(Spree::Product, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']).to have_key('details')
      end
    end

    context 'with top-level prices (simple-product flow)' do
      it 'forwards prices to the auto-created default variant' do
        post :create, params: {
          name: 'Simple Product',
          prices: [
            { currency: 'USD', amount: 12.50 },
            { currency: 'EUR', amount: 11.00, compare_at_amount: 13.99 }
          ]
        }, as: :json

        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'Simple Product')
        usd = created.default_variant.prices.find_by(currency: 'USD')
        eur = created.default_variant.prices.find_by(currency: 'EUR')
        expect(usd.amount).to eq(12.50)
        expect(eur.amount).to eq(11.00)
        expect(eur.compare_at_amount).to eq(13.99)
      end

      # The Admin API contract is canonical decimal strings (`"29.99"`, period
      # decimal). Clients (the dashboard) normalize localized input
      # client-side before sending — the API is not asked to parse comma-vs-
      # period. See docs/plans/5.5-client-side-money-normalization.md. (The
      # models still tolerate localized input for the legacy Rails admin, but
      # that is not part of the Admin API contract and is covered by the
      # `Spree::LocalizedNumber` unit specs.)
      it 'accepts amounts as canonical decimal strings (symmetric with reads)' do
        post :create, params: {
          name: 'String Price Product',
          prices: [
            { currency: 'USD', amount: '29.99', compare_at_amount: '39.99' }
          ]
        }, as: :json

        expect(response).to have_http_status(:created)
        price = Spree::Product.find_by(name: 'String Price Product').default_variant.prices.find_by(currency: 'USD')
        expect(price.amount).to eq(29.99)
        expect(price.compare_at_amount).to eq(39.99)
      end
    end

    context 'with inline media' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'test-image.jpg',
          content_type: 'image/jpeg'
        )
      end

      it 'attaches media inline on create' do
        expect {
          post :create, params: {
            name: 'Product With Media',
            media: [
              { signed_id: blob.signed_id, alt: 'A cat thinking', position: 1 }
            ]
          }, as: :json
        }.to change(Spree::Product, :count).by(1)
                                           .and change(Spree::Asset, :count).by(1)

        expect(response).to have_http_status(:created)

        created = Spree::Product.find_by(name: 'Product With Media')
        expect(created.media.count).to eq(1)
        media = created.media.first
        expect(media.alt).to eq('A cat thinking')
        expect(media.attachment).to be_attached
        expect(media.type).to eq('Spree::Image')
      end

      it 'rejects an unknown media type' do
        post :create, params: {
          name: 'Product Bad Type',
          media: [
            { signed_id: blob.signed_id, type: 'NotAClass' }
          ]
        }, as: :json

        # Product created, but the bad media entry was silently skipped —
        # ApplyMedia is strict about ALLOWED_MEDIA_TYPES.
        expect(response).to have_http_status(:created)
        created = Spree::Product.find_by(name: 'Product Bad Type')
        expect(created.media).to be_empty
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
          p.default_variant.update!(sku: 'OLD-SKU')
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

      it "ignores a category that belongs to another store's taxonomy" do
        foreign_taxon = create(:taxon, taxonomy: create(:taxonomy, store: create(:store)))

        patch :update, params: {
          id: product.prefixed_id,
          category_ids: [category1.prefixed_id, foreign_taxon.prefixed_id]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.taxons).to include(category1)
        expect(product.reload.taxons).not_to include(foreign_taxon)
      end
    end

    context 'with tags' do
      it 'updates product tags' do
        patch :update, params: { id: product.prefixed_id, tags: ['new-tag', 'sale'] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.tag_list).to match_array(['new-tag', 'sale'])
      end
    end

    context 'with product_publications' do
      let!(:pos_channel)       { create(:channel, store: store, code: 'pos', name: 'POS') }
      let!(:wholesale_channel) { create(:channel, store: store, code: 'wholesale', name: 'Wholesale') }
      let(:default_channel)    { store.default_channel }
      let!(:existing_publication) do
        product.product_publications.find_by(channel: default_channel) ||
          product.product_publications.create!(channel: default_channel)
      end

      it 'attaches a new channel via product_publications' do
        patch :update, params: {
          id: product.prefixed_id,
          product_publications: [
            { channel_id: default_channel.prefixed_id },
            { channel_id: pos_channel.prefixed_id }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.channels).to contain_exactly(default_channel, pos_channel)
      end

      it 'is idempotent when re-submitting an existing channel by channel_id' do
        patch :update, params: {
          id: product.prefixed_id,
          product_publications: [{ channel_id: default_channel.prefixed_id }]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.product_publications.where(channel_id: default_channel.id).pluck(:id))
          .to eq([existing_publication.id])
      end

      it 'detaches every channel when given an empty array' do
        product.product_publications.create!(channel: pos_channel)

        patch :update, params: {
          id: product.prefixed_id,
          product_publications: []
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.product_publications).to be_empty
      end

      it 'persists the published_at window submitted with the channel' do
        Timecop.freeze do
          future = 2.days.from_now.change(usec: 0)

          patch :update, params: {
            id: product.prefixed_id,
            product_publications: [
              { channel_id: default_channel.prefixed_id, published_at: future.iso8601 },
              { channel_id: wholesale_channel.prefixed_id }
            ]
          }, as: :json

          expect(response).to have_http_status(:ok)
          publication = product.reload.product_publications.find_by(channel: default_channel)
          expect(publication.published_at).to be_within(1.second).of(future)
        end
      end

      it 'removes channels absent from the payload' do
        product.product_publications.create!(channel: pos_channel)

        patch :update, params: {
          id: product.prefixed_id,
          product_publications: [{ channel_id: default_channel.prefixed_id }]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.channels).to contain_exactly(default_channel)
      end

      it "ignores a channel that belongs to another store" do
        foreign_channel = create(:channel, store: create(:store), code: 'foreign')

        patch :update, params: {
          id: product.prefixed_id,
          product_publications: [
            { channel_id: pos_channel.prefixed_id },
            { channel_id: foreign_channel.prefixed_id }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload.channels).to include(pos_channel)
        expect(product.reload.channels).not_to include(foreign_channel)
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

    context 'with inline custom fields' do
      let!(:material_definition) do
        create(:metafield_definition,
               resource_type: 'Spree::Product',
               namespace: 'product',
               key: 'material',
               metafield_type: 'Spree::Metafields::ShortText')
      end
      let!(:fit_definition) do
        create(:metafield_definition,
               resource_type: 'Spree::Product',
               namespace: 'product',
               key: 'fit',
               metafield_type: 'Spree::Metafields::ShortText')
      end
      let!(:waterproof_definition) do
        create(:metafield_definition,
               resource_type: 'Spree::Product',
               namespace: 'product',
               key: 'waterproof',
               metafield_type: 'Spree::Metafields::Boolean')
      end

      it 'creates new custom field values on PATCH' do
        expect {
          patch :update, params: {
            id: product.prefixed_id,
            custom_fields: [
              { custom_field_definition_id: material_definition.prefixed_id, value: 'Wool' }
            ]
          }, as: :json
        }.to change(Spree::Metafield, :count).by(1)

        expect(response).to have_http_status(:ok)
        metafield = product.metafields.find_by(metafield_definition: material_definition)
        expect(metafield.value).to eq('Wool')
      end

      it 'upserts an existing custom field value by definition id' do
        existing = product.metafields.create!(
          metafield_definition: material_definition,
          value: 'Cotton'
        )

        patch :update, params: {
          id: product.prefixed_id,
          custom_fields: [
            { custom_field_definition_id: material_definition.prefixed_id, value: 'Polyester' }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(existing.reload.value).to eq('Polyester')
        expect(product.metafields.where(metafield_definition: material_definition).count).to eq(1)
      end

      it 'leaves unrelated custom fields untouched on partial PATCH' do
        product.metafields.create!(metafield_definition: material_definition, value: 'Cotton')
        product.metafields.create!(metafield_definition: fit_definition, value: 'Regular')

        patch :update, params: {
          id: product.prefixed_id,
          custom_fields: [
            { custom_field_definition_id: fit_definition.prefixed_id, value: 'Slim' }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.metafields.count).to eq(2)
        expect(product.metafields.find_by(metafield_definition: material_definition).value).to eq('Cotton')
        expect(product.metafields.find_by(metafield_definition: fit_definition).value).to eq('Slim')
      end

      it 'destroys an existing custom field when value is blank on PATCH' do
        existing = product.metafields.create!(
          metafield_definition: material_definition,
          value: 'Cotton'
        )

        expect {
          patch :update, params: {
            id: product.prefixed_id,
            custom_fields: [
              { custom_field_definition_id: material_definition.prefixed_id, value: '' }
            ]
          }, as: :json
        }.to change(Spree::Metafield, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(Spree::Metafield.find_by(id: existing.id)).to be_nil
      end

      it 'persists a Boolean false value instead of treating it as blank' do
        existing = product.metafields.create!(
          metafield_definition: waterproof_definition,
          value: true
        )

        expect {
          patch :update, params: {
            id: product.prefixed_id,
            custom_fields: [
              { custom_field_definition_id: waterproof_definition.prefixed_id, value: false }
            ]
          }, as: :json
        }.not_to change(Spree::Metafield, :count)

        expect(response).to have_http_status(:ok)
        # Boolean metafields store as a stringified value; the entry should
        # still exist with the new false value.
        expect(existing.reload.value).to be_in(['false', 'f', false])
      end

      it 'skips entries with a blank custom_field_definition_id' do
        expect {
          patch :update, params: {
            id: product.prefixed_id,
            custom_fields: [
              { value: 'Orphan' },
              { custom_field_definition_id: material_definition.prefixed_id, value: 'Linen' }
            ]
          }, as: :json
        }.to change(Spree::Metafield, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(product.metafields.find_by(metafield_definition: material_definition).value).to eq('Linen')
      end

      it 'accepts a raw (non-prefixed) custom_field_definition_id' do
        patch :update, params: {
          id: product.prefixed_id,
          custom_fields: [
            { custom_field_definition_id: material_definition.id, value: 'Velvet' }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.metafields.find_by(metafield_definition: material_definition).value).to eq('Velvet')
      end
    end

    context 'with inline media' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'test-image.jpg',
          content_type: 'image/jpeg'
        )
      end

      it 'creates a new media item from a signed_id' do
        expect {
          patch :update, params: {
            id: product.prefixed_id,
            media: [
              { signed_id: blob.signed_id, alt: 'A cat', position: 1 }
            ]
          }, as: :json
        }.to change(Spree::Asset, :count).by(1)

        expect(response).to have_http_status(:ok)
        media = product.media.find_by(alt: 'A cat')
        expect(media).to be_present
        expect(media.attachment).to be_attached
      end

      it 'patches an existing media item by id' do
        existing = product.media.build(alt: 'Old', position: 1, type: 'Spree::Image')
        existing.attachment.attach(blob)
        existing.save!

        patch :update, params: {
          id: product.prefixed_id,
          media: [
            { id: existing.prefixed_id, alt: 'New alt text', position: 5 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        existing.reload
        expect(existing.alt).to eq('New alt text')
        expect(existing.position).to eq(5)
      end

      it 'assigns variant_ids when patching an existing media item' do
        variant = create(:variant, product: product)
        existing = product.media.build(alt: 'Variant linked', position: 1, type: 'Spree::Image')
        existing.attachment.attach(blob)
        existing.save!

        patch :update, params: {
          id: product.prefixed_id,
          media: [
            { id: existing.prefixed_id, variant_ids: [variant.prefixed_id] }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(existing.reload.variant_ids).to include(variant.id)
      end

      it 'leaves persisted media untouched when omitted from the payload' do
        kept = product.media.build(alt: 'Kept', position: 1, type: 'Spree::Image')
        kept.attachment.attach(blob)
        kept.save!

        expect {
          patch :update, params: {
            id: product.prefixed_id,
            media: [
              { signed_id: blob.signed_id, alt: 'New entry', position: 2 }
            ]
          }, as: :json
        }.to change(Spree::Asset, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(product.media.where(id: kept.id)).to exist
        expect(kept.reload.alt).to eq('Kept')
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
    let!(:other_store_product) { create(:product, store: other_store, status: 'active') }

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

  describe 'POST #bulk_add_to_collections' do
    let!(:collection) { create(:collection, store: store) }
    let!(:other_collection) { create(:collection, store: store) }
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    it 'adds every product to every collection' do
      post :bulk_add_to_collections, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        collection_ids: [collection.prefixed_id, other_collection.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'collection_count' => 2)
      expect(product.reload.collections).to include(collection, other_collection)
      expect(second_product.reload.collections).to include(collection, other_collection)
    end

    it 'silently ignores collections from other stores' do
      foreign_collection = create(:collection, store: create(:store))

      post :bulk_add_to_collections, params: {
        ids: [product.prefixed_id],
        collection_ids: [collection.prefixed_id, foreign_collection.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['collection_count']).to eq(1)
      expect(product.reload.collections).to include(collection)
      expect(product.reload.collections).not_to include(foreign_collection)
    end

    it 'silently ignores automatic collections (curation is manual-only)' do
      automatic = create(:automatic_collection, store: store)

      post :bulk_add_to_collections, params: {
        ids: [product.prefixed_id],
        collection_ids: [collection.prefixed_id, automatic.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['collection_count']).to eq(1)
      expect(product.reload.collections).to include(collection)
      expect(product.reload.collections).not_to include(automatic)
    end

    it 'silently drops products from other stores' do
      other_store_product = create(:product, store: create(:store))

      post :bulk_add_to_collections, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id],
        collection_ids: [collection.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(other_store_product.reload.collections).to be_empty
    end

    it 'returns 422 when ids is missing' do
      post :bulk_add_to_collections, params: { collection_ids: [collection.prefixed_id] }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST #bulk_remove_from_collections' do
    let!(:collection) { create(:collection, store: store) }
    let!(:second_product) { create(:product) }

    before do
      request.headers.merge!(headers)
      Spree::Collections::AddProducts.call(collections: [collection], products: [product, second_product])
    end

    it 'removes every product from every collection' do
      post :bulk_remove_from_collections, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        collection_ids: [collection.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'collection_count' => 1)
      expect(product.reload.collections).not_to include(collection)
      expect(second_product.reload.collections).not_to include(collection)
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

    it 'attaches to a taxonomy-less, store-owned category' do
      # Regression: categories were scoped via the through-taxonomy association,
      # which misses store-owned categories that have no taxonomy.
      store_category = Spree::Category.create!(name: 'Store Owned', store: store)

      post :bulk_add_to_categories, params: {
        ids: [product.prefixed_id],
        category_ids: [store_category.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['category_count']).to eq(1)
      expect(product.reload.taxons).to include(store_category)
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
      other_store_product = create(:product, store: other_store)

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
        product.reload.classifications.find_by(category: category).position,
        second_product.reload.classifications.find_by(category: category).position
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
        survivor.reload.classifications.find_by(category: category)&.position,
        latecomer.reload.classifications.find_by(category: category)&.position
      ].compact.sort

      expect(positions).to eq([1, 2])
    end

  end

  describe 'POST #bulk_add_to_channels' do
    let!(:channel_a) { create(:channel, store: store, name: 'Channel A', code: 'channel-a') }
    let!(:channel_b) { create(:channel, store: store, name: 'Channel B', code: 'channel-b') }
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    it 'publishes every product on every channel' do
      post :bulk_add_to_channels, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        channel_ids: [channel_a.prefixed_id, channel_b.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2, 'channel_count' => 2)
      expect(channel_a.reload.products).to include(product, second_product)
      expect(channel_b.reload.products).to include(product, second_product)
    end

    it 'silently ignores channels from other stores' do
      foreign_channel = create(:channel, store: create(:store), code: 'foreign')

      post :bulk_add_to_channels, params: {
        ids: [product.prefixed_id],
        channel_ids: [channel_a.prefixed_id, foreign_channel.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['channel_count']).to eq(1)
      expect(channel_a.reload.products).to include(product)
      expect(foreign_channel.reload.products).not_to include(product)
    end

    it 'silently drops products from other stores' do
      other_store = create(:store)
      other_store_product = create(:product, store: other_store)

      post :bulk_add_to_channels, params: {
        ids: [product.prefixed_id, other_store_product.prefixed_id],
        channel_ids: [channel_a.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(channel_a.reload.products).not_to include(other_store_product)
    end

  end

  describe 'POST #bulk_remove_from_channels' do
    let!(:channel_a) { create(:channel, store: store, name: 'Channel A', code: 'channel-a') }
    let!(:channel_b) { create(:channel, store: store, name: 'Channel B', code: 'channel-b') }
    let!(:second_product) { create(:product) }

    before do
      request.headers.merge!(headers)
      channel_a.add_products([product.id, second_product.id])
      channel_b.add_products([product.id])
    end

    it 'unpublishes every listed product from every listed channel' do
      post :bulk_remove_from_channels, params: {
        ids: [product.prefixed_id, second_product.prefixed_id],
        channel_ids: [channel_a.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('product_count' => 2, 'channel_count' => 1, 'removed' => 2)
      expect(channel_a.reload.products).not_to include(product, second_product)
      expect(channel_b.reload.products).to include(product)
    end

    it 'silently ignores channels from other stores' do
      foreign_channel = create(:channel, store: create(:store), code: 'foreign')
      foreign_channel.add_products([product.id])

      post :bulk_remove_from_channels, params: {
        ids: [product.prefixed_id],
        channel_ids: [channel_a.prefixed_id, foreign_channel.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['channel_count']).to eq(1)
      expect(foreign_channel.reload.products).to include(product)
    end

  end

  describe 'POST #bulk_add_tags' do
    let!(:second_product) { create(:product) }

    before { request.headers.merge!(headers) }

    # Tag changes flip automatic-collection matches; after_bulk_tags_change kicks
    # bulk_auto_match_collections, which enqueues one job per live (non-deleted,
    # non-archived) product, and only when the store has automatic collections.
    describe 'auto matching collections' do
      let!(:active_a) { create(:product, status: :active) }
      let!(:active_b) { create(:product, status: :active) }
      let!(:archived) { create(:product, status: :archived) }
      let!(:soft_deleted) { create(:product, status: :draft, deleted_at: Time.current) }

      let(:bulk_ids) { [active_a, active_b, archived, soft_deleted].map(&:prefixed_id) }

      context 'on a store with automatic collections' do
        let!(:auto_collection) { create(:automatic_collection, store: store) }

        it 'auto matches collections in bulk only for live active products' do
          expect do
            post :bulk_add_tags, params: { ids: bulk_ids, tags: ['summer'] }, as: :json
          end.to have_enqueued_job(Spree::Products::AutoMatchCollectionsJob)
            .on_queue(Spree.queues.collections)
            .exactly(:twice)

          jobs = Spree::Products::AutoMatchCollectionsJob.queue_adapter.enqueued_jobs.last(2)
          expect(jobs.map { |job| job['arguments'] }).to contain_exactly(
            [active_a.id], [active_b.id]
          )
        end
      end

      context 'on a store without any automatic collections' do
        it 'skips auto matching collections' do
          expect do
            post :bulk_add_tags, params: { ids: bulk_ids, tags: ['summer'] }, as: :json
          end.not_to have_enqueued_job(Spree::Products::AutoMatchCollectionsJob)
        end
      end
    end

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
      other_store_product = create(:product, store: other_store)

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
      other_store_product = create(:product, store: other_store)

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
      other_store_product = create(:product, store: other_store)

      delete :bulk_destroy, params: {
        ids: [other_store_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0)
      expect(other_store_product.reload.deleted_at).to be_nil
    end
  end

  describe 'translations matrix on show' do
    before do
      configure_supported_locales(store, %w[en de fr])
      request.headers.merge!(headers)
    end

    it 'returns the matrix only when ?expand=translations is requested' do
      Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine') }

      get :show, params: { id: product.prefixed_id }, as: :json
      expect(json_response).not_to have_key('translations')

      get :show, params: { id: product.prefixed_id, expand: 'translations' }, as: :json
      expect(json_response['translations']['de']['name']).to eq('Espressomaschine')
    end
  end
end
