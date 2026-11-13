require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoreController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:store) do
    create(:store, name: 'Coffee Shop', default_locale: 'en',
                   seo_title: 'Coffee Shop — Fresh Beans', meta_description: 'Freshly roasted coffee',
                   meta_keywords: 'coffee, beans', facebook: 'https://facebook.com/coffeeshop',
                   twitter: 'coffeeshop', instagram: 'coffeeshop.beans',
                   customer_support_email: 'help@coffee.example', mail_from_address: 'orders@coffee.example',
                   new_order_notifications_email: 'staff@coffee.example')
  end

  before do
    allow(store).to receive(:supported_locales_list).and_return(%w[en de fr])
    store.upsert_translations('de' => { 'seo_title' => 'Kaffeeladen — Frische Bohnen', 'meta_keywords' => 'Kaffee, Bohnen' })
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
      expect(json_response['meta_keywords']).to eq('coffee, beans')
    end

    it 'returns the branding, social accounts and public email addresses' do
      get :show

      expect(json_response).to include(
        'facebook' => 'https://facebook.com/coffeeshop',
        'twitter' => 'coffeeshop',
        'instagram' => 'coffeeshop.beans',
        'customer_support_email' => 'help@coffee.example',
        'mail_from_address' => 'orders@coffee.example',
        'logo_url' => nil
      )
    end

    it 'returns the logo as a full URL' do
      store.logo.attach(io: File.open(Spree::Core::Engine.root.join('spec/fixtures/thinking-cat.jpg')), filename: 'logo.jpg')

      get :show

      expect(json_response['logo_url']).to start_with('http').and include('logo.jpg')
    end

    it 'returns the translation for the requested locale' do
      request.headers['x-spree-locale'] = 'de'

      get :show

      expect(json_response['seo_title']).to eq('Kaffeeladen — Frische Bohnen')
      expect(json_response['meta_keywords']).to eq('Kaffee, Bohnen')
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

      expect(json_response.keys).to match_array(%w[id name seo_title meta_description meta_keywords logo_url
                                                   facebook twitter instagram customer_support_email mail_from_address])
    end
  end
end
