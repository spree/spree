require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoreController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:store) do
    create(:store, name: 'Coffee Shop', default_locale: 'en',
                   seo_title: 'Coffee Shop — Fresh Beans', meta_description: 'Freshly roasted coffee')
  end

  before do
    allow(store).to receive(:supported_locales_list).and_return(%w[en de fr])
    store.translations.create!(locale: 'de', seo_title: 'Kaffeeladen — Frische Bohnen')
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after { I18n.locale = :en }

  describe 'GET #show' do
    it 'returns the current store with its default-locale SEO values' do
      get :show

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store.prefixed_id)
      expect(json_response['name']).to eq('Coffee Shop')
      expect(json_response['seo_title']).to eq('Coffee Shop — Fresh Beans')
      expect(json_response['meta_description']).to eq('Freshly roasted coffee')
    end

    it 'returns the translation for the requested locale' do
      request.headers['x-spree-locale'] = 'de'

      get :show

      expect(json_response['seo_title']).to eq('Kaffeeladen — Frische Bohnen')
    end

    it 'falls back to the default locale for a field without a translation' do
      request.headers['x-spree-locale'] = 'de'

      get :show

      expect(json_response['meta_description']).to eq('Freshly roasted coffee')
    end

    it 'falls back to the default locale for a supported locale with no translations' do
      request.headers['x-spree-locale'] = 'fr'

      get :show

      expect(json_response['seo_title']).to eq('Coffee Shop — Fresh Beans')
    end

    it 'does not expose back-office store settings' do
      get :show

      expect(json_response.keys).to match_array(%w[id name seo_title meta_description])
    end
  end
end
