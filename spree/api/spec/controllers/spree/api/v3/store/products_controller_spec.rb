require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:product2) { create(:product, status: 'active') }
  let!(:draft_product) { create(:product, status: 'draft') }
  let!(:other_store) { create(:store) }
  let!(:other_store_product) { create(:product, store: other_store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = store.default_locale
  end

  describe 'seller' do
    let!(:seller) { create(:seller, store: store, name: 'Sparks Audio', status: 'approved') }
    let!(:seller_product) { create(:product, store: store, seller: seller, status: 'active') }

    # Always present so a storefront can group or link by seller without
    # paying for the expand.
    it 'exposes seller_id without an expand' do
      get :show, params: { id: seller_product.slug }, as: :json

      expect(json_response['seller_id']).to eq(seller.prefixed_id)
      expect(json_response).not_to have_key('seller')
    end

    it 'embeds the public profile on expand' do
      get :show, params: { id: seller_product.slug, expand: 'seller' }, as: :json

      expect(json_response['seller']['name']).to eq('Sparks Audio')
      # The storefront never sees how the marketplace runs the seller.
      expect(json_response['seller']).not_to have_key('status')
      expect(json_response['seller']).not_to have_key('tax_remittance')
    end

    it 'leaves seller_id nil on a first-party product' do
      get :show, params: { id: product.slug }, as: :json

      expect(json_response['seller_id']).to be_nil
    end
  end

  describe 'GET #index' do
    it 'returns a list of products' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
    end

    it 'returns product attributes' do
      get :index

      product_data = json_response['data'].first
      expect(product_data).to include('id', 'name', 'slug')
    end

    it 'returns pagination metadata' do
      get :index, params: { page: 1, limit: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['meta']).to include(
        'page' => 1,
        'limit' => 1,
        'count' => 2,
        'pages' => 2
      )
    end

    it 'respects max limit limit' do
      get :index, params: { limit: 500 }

      expect(json_response['meta']['limit']).to eq(100)
    end

    # The storefront accepts the same `cf_*` sort values and `q[...]` filter
    # predicates as the Admin API — both route through the search provider.
    context 'with custom field filtering and sorting' do
      let!(:definition) do
        create(:custom_field_definition, :short_text_field, :searchable, :sortable,
               namespace: 'custom', key: 'warranty')
      end

      before do
        product.set_custom_field(definition, '2 Years')
        product2.set_custom_field(definition, '90 Days')
      end

      it 'filters by a cf_* predicate' do
        get :index, params: { q: { cf_custom_warranty_i_cont: '2 years' } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |p| p['id'] }).to eq([product.prefixed_id])
      end

      it 'sorts by a cf_* attribute' do
        get :index, params: { sort: '-cf_custom_warranty' }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |p| p['id'] }).to eq([product2.prefixed_id, product.prefixed_id])
      end

      it 'ignores unknown cf_* predicates instead of erroring' do
        get :index, params: { q: { cf_bogus_field_eq: 'x' } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(2)
      end
    end

    context 'store scoping' do
      it 'does not return products from other stores' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(other_store_product.prefixed_id)
      end
    end

    context 'status scoping' do
      it 'does not return draft products' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(draft_product.prefixed_id)
      end
    end

    context 'currency scoping' do
      let!(:eur_only_product) do
        create(:product, status: 'active').tap do |p|
          p.default_variant.prices.delete_all
          p.default_variant.set_price('EUR', 20.0)
        end
      end

      before do
        allow(store).to receive(:supported_currencies_list).and_return([Money::Currency.find('USD'), Money::Currency.find('EUR')])
        stub_store_preferences(show_products_without_price: false)
      end

      it 'only returns products with prices in the current currency' do
        request.headers['x-spree-currency'] = 'USD'
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(product.prefixed_id)
        expect(ids).to include(product2.prefixed_id)
        expect(ids).not_to include(eur_only_product.prefixed_id)
      end

      it 'returns EUR products when EUR currency is requested' do
        request.headers['x-spree-currency'] = 'EUR'
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(eur_only_product.prefixed_id)
        expect(ids).not_to include(product.prefixed_id)
      end
    end

    context 'ransack filtering' do
      it 'filters products by name' do
        get :index, params: { q: { name_cont: product.name } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].first['id']).to eq(product.prefixed_id)
      end

      # Regression for SPA pickers (`<ResourceMultiAutocomplete>` hydration):
      # the store products controller routes filters through
      # `SearchProviderSupport#search_filters`, which bypasses the base
      # `ransack_params` decoder. Without explicit decoding there, hydration
      # calls like `q[id_in][]=prod_…` return zero rows.
      context 'with q[id_in] using prefixed IDs' do
        it 'decodes prefixed IDs and returns matching rows' do
          get :index, params: { q: { id_in: [product.prefixed_id, product2.prefixed_id] } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to contain_exactly(product.prefixed_id, product2.prefixed_id)
        end

        it 'still accepts raw integer IDs' do
          get :index, params: { q: { id_in: [product.id] } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to eq([product.prefixed_id])
        end

        it 'decodes with q[id_eq] too' do
          get :index, params: { q: { id_eq: product2.prefixed_id } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to eq([product2.prefixed_id])
        end
      end

      context 'filtering by option values' do
        let(:option_type) { create(:option_type, :color) }
        let(:option_value_red) { create(:option_value, option_type: option_type, name: 'red', presentation: 'Red') }
        let(:option_value_blue) { create(:option_value, option_type: option_type, name: 'blue', presentation: 'Blue') }
        let!(:product_with_red) do
          create(:product, status: 'active', option_types: [option_type]).tap do |p|
            create(:variant, product: p, option_values: [option_value_red], price: 25.0)
          end
        end
        let!(:product_with_blue) do
          create(:product, status: 'active', option_types: [option_type]).tap do |p|
            create(:variant, product: p, option_values: [option_value_blue], price: 75.0)
          end
        end

        it 'filters products by option value prefixed IDs' do
          get :index, params: { q: { with_option_value_ids: [option_value_red.prefixed_id] } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to include(product_with_red.prefixed_id)
          expect(ids).not_to include(product_with_blue.prefixed_id)
        end

        it 'filters products by price range and option values combined' do
          get :index, params: { q: { with_option_value_ids: [option_value_red.prefixed_id, option_value_blue.prefixed_id], price_between: [50, 100] } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to include(product_with_blue.prefixed_id)
          expect(ids).not_to include(product_with_red.prefixed_id)
        end

        it 'sorts by price while filtering by option values' do
          get :index, params: { sort: 'price', q: { with_option_value_ids: [option_value_red.prefixed_id, option_value_blue.prefixed_id] } }

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |p| p['id'] }
          expect(ids).to include(product_with_red.prefixed_id, product_with_blue.prefixed_id)
        end
      end
    end

    context 'sorting' do
      let!(:cheap_product) do
        create(:product, status: 'active', name: 'Cheap').tap do |p|
          p.default_variant.prices.first.update!(amount: 10.0)
        end
      end

      let!(:expensive_product) do
        create(:product, status: 'active', name: 'Expensive').tap do |p|
          p.default_variant.prices.first.update!(amount: 100.0)
        end
      end

      it 'sorts by price low to high' do
        get :index, params: { sort: 'price' }

        expect(response).to have_http_status(:ok)
        prices = json_response['data'].map { |p| p['price']['amount'].to_f }
        expect(prices).to eq(prices.sort)
      end

      it 'sorts by price high to low' do
        get :index, params: { sort: '-price' }

        expect(response).to have_http_status(:ok)
        prices = json_response['data'].map { |p| p['price']['amount'].to_f }
        expect(prices).to eq(prices.sort.reverse)
      end

      it 'paginates correctly when sorting by price' do
        get :index, params: { sort: 'price', page: 1, limit: 1 }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['meta']['pages']).to be >= 2
      end

      it 'paginates correctly when sorting by price descending' do
        get :index, params: { sort: '-price', page: 1, limit: 1 }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['meta']['pages']).to be >= 2
      end

      it 'sorts by best selling' do
        product.update!(units_sold_count: 10, revenue: 100)
        product2.update!(units_sold_count: 50, revenue: 500)

        get :index, params: { sort: 'best_selling' }

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids.first).to eq(product2.prefixed_id)
      end

      it 'sorts by name a-z' do
        get :index, params: { sort: 'name' }

        expect(response).to have_http_status(:ok)
        names = json_response['data'].map { |p| p['name'] }
        expect(names).to eq(names.sort)
      end

      # Regression test: combining in_stock filter with price sorting caused
      # PG::UndefinedTable due to table alias conflicts on spree_variants
      it 'sorts by price while filtering in_stock' do
        get :index, params: { sort: '-price', q: { in_stock: true } }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'authentication' do
      context 'without API key' do
        before { request.headers['X-Spree-Api-Key'] = nil }

        it 'returns unauthorized' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['code']).to eq('invalid_token')
          expect(json_response['error']['message']).to be_present
        end
      end

      context 'with invalid API key' do
        before { request.headers['X-Spree-Api-Key'] = 'invalid' }

        it 'returns unauthorized' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['code']).to eq('invalid_token')
        end
      end
    end
  end

  describe 'GET #show' do
    context 'finding by slug' do
      it 'returns a product by slug' do
        get :show, params: { id: product.slug }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(product.prefixed_id)
        expect(json_response['name']).to eq(product.name)
        expect(json_response['slug']).to eq(product.slug)
      end
    end

    context 'finding by prefix_id' do
      it 'returns a product by prefix_id' do
        get :show, params: { id: product.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(product.prefixed_id)
        expect(json_response['name']).to eq(product.name)
        expect(json_response['slug']).to eq(product.slug)
      end
    end

    context 'with translations', if: Spree::Product.include?(Spree::TranslatableResource) do
      let!(:translated_product) do
        create(:product, status: 'active', name: 'English Product', slug: 'english-product').tap do |p|
          Mobility.with_locale(:fr) do
            p.name = 'Produit Français'
            p.slug = 'produit-francais'
            p.save!
          end
        end
      end

      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en fr])
        allow(store).to receive(:default_locale).and_return('en')
      end

      it 'finds product by English slug with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: 'english-product' }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('English Product')
        expect(json_response['slug']).to eq('english-product')
      end

      it 'finds product by French slug with French locale' do
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: 'produit-francais' }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Produit Français')
        expect(json_response['slug']).to eq('produit-francais')
      end

      it 'returns translated content based on locale header' do
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: translated_product.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Produit Français')
      end

      it 'returns 404 when searching French slug with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: 'produit-francais' }

        expect(response).to have_http_status(:not_found)
      end

      context 'locale fallback' do
        let!(:english_only_product) do
          create(:product, status: 'active', name: 'English Only', slug: 'english-only')
        end

        it 'falls back to default locale when product has no translation in requested locale' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: 'english-only' }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(english_only_product.prefixed_id)
          # Name returns English since no French translation exists
          expect(json_response['name']).to eq('English Only')
        end

        it 'returns translated content when translation exists' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: 'english-product' }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(translated_product.prefixed_id)
          expect(json_response['name']).to eq('Produit Français')
        end
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent product' do
        get :show, params: { id: 'non-existent-slug' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for product from another store' do
        get :show, params: { id: other_store_product.slug }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for draft product' do
        get :show, params: { id: draft_product.slug }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'locale and currency headers' do
    context 'x-spree-locale header' do
      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en fr])
        allow(store).to receive(:default_locale).and_return('en')
      end

      it 'sets locale from header' do
        request.headers['x-spree-locale'] = 'fr'
        get :index

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:fr)
      end

      it 'falls back to default locale for unsupported locale' do
        request.headers['x-spree-locale'] = 'de'
        get :index

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:en)
      end
    end

    context 'x-spree-currency header' do
      before do
        allow(store).to receive(:supported_currencies_list).and_return([Money::Currency.find('USD'), Money::Currency.find('EUR')])
        allow(store).to receive(:default_currency).and_return('USD')
      end

      it 'sets currency from header' do
        request.headers['x-spree-currency'] = 'EUR'
        get :index

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('EUR')
      end

      it 'falls back to default currency for unsupported currency' do
        request.headers['x-spree-currency'] = 'GBP'
        get :index

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('USD')
      end
    end
  end
end
