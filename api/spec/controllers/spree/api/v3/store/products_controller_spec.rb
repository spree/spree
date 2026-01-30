require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }
  let!(:product2) { create(:product, stores: [store], status: 'active') }
  let!(:draft_product) { create(:product, stores: [store], status: 'draft') }
  let!(:other_store) { create(:store) }
  let!(:other_store_product) { create(:product, stores: [other_store]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = store.default_locale
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
      get :index, params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['meta']).to include(
        'page' => 1,
        'limit' => 1,
        'count' => 2,
        'pages' => 2
      )
    end

    it 'respects max per_page limit' do
      get :index, params: { per_page: 500 }

      expect(json_response['meta']['limit']).to eq(100)
    end

    context 'store scoping' do
      it 'does not return products from other stores' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(other_store_product.prefix_id)
      end
    end

    context 'status scoping' do
      it 'does not return draft products' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(draft_product.prefix_id)
      end
    end

    context 'currency scoping' do
      let!(:eur_only_product) do
        create(:product, stores: [store], status: 'active').tap do |p|
          p.master.prices.delete_all
          p.master.set_price('EUR', 20.0)
        end
      end

      before do
        allow(store).to receive(:supported_currencies_list).and_return([Money::Currency.find('USD'), Money::Currency.find('EUR')])
        Spree::Config.show_products_without_price = false
      end

      it 'only returns products with prices in the current currency' do
        request.headers['x-spree-currency'] = 'USD'
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(product.prefix_id)
        expect(ids).to include(product2.prefix_id)
        expect(ids).not_to include(eur_only_product.prefix_id)
      end

      it 'returns EUR products when EUR currency is requested' do
        request.headers['x-spree-currency'] = 'EUR'
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(eur_only_product.prefix_id)
        expect(ids).not_to include(product.prefix_id)
      end
    end

    context 'ransack filtering' do
      it 'filters products by name' do
        get :index, params: { q: { name_cont: product.name } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].first['id']).to eq(product.prefix_id)
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
        expect(json_response['id']).to eq(product.prefix_id)
        expect(json_response['name']).to eq(product.name)
        expect(json_response['slug']).to eq(product.slug)
      end
    end

    context 'finding by prefix_id' do
      it 'returns a product by prefix_id' do
        get :show, params: { id: product.prefix_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(product.prefix_id)
        expect(json_response['name']).to eq(product.name)
        expect(json_response['slug']).to eq(product.slug)
      end
    end

    context 'with translations', if: Spree::Product.include?(Spree::TranslatableResource) do
      let!(:translated_product) do
        create(:product, stores: [store], status: 'active', name: 'English Product', slug: 'english-product').tap do |p|
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
        get :show, params: { id: translated_product.prefix_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Produit Français')
      end

      it 'returns 404 when searching French slug with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: 'produit-francais' }

        expect(response).to have_http_status(:not_found)
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
