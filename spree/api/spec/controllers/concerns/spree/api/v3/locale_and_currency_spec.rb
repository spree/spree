require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = :en
  end

  describe 'Spree::Api::V3::LocaleAndCurrency' do
    describe 'locale resolution' do
      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en fr de])
        allow(store).to receive(:default_locale).and_return('en')
      end

      it 'sets locale from x-spree-locale header' do
        request.headers['x-spree-locale'] = 'fr'
        get :index

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:fr)
      end

      it 'sets locale from params' do
        get :index, params: { locale: 'fr' }

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:fr)
      end

      it 'prefers header over params' do
        request.headers['x-spree-locale'] = 'de'
        get :index, params: { locale: 'fr' }

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:de)
      end

      it 'falls back to store default locale for unsupported locale' do
        request.headers['x-spree-locale'] = 'ja'
        get :index

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:en)
      end

      it 'falls back to store default locale when no locale specified' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:en)
      end

      it 'resolves current_locale correctly' do
        request.headers['x-spree-locale'] = 'fr'
        get :index

        expect(controller.send(:current_locale)).to eq('fr')
      end
    end

    describe 'currency resolution' do
      before do
        allow(store).to receive(:supported_currencies_list).and_return(
          [Money::Currency.find('USD'), Money::Currency.find('EUR')]
        )
        allow(store).to receive(:default_currency).and_return('USD')
      end

      it 'sets currency from x-spree-currency header' do
        request.headers['x-spree-currency'] = 'EUR'
        get :index

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('EUR')
      end

      it 'sets currency from params' do
        get :index, params: { currency: 'EUR' }

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('EUR')
      end

      it 'falls back to store default currency for unsupported currency' do
        request.headers['x-spree-currency'] = 'GBP'
        get :index

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('USD')
      end
    end

    describe 'market-aware locale resolution' do
      let!(:germany) { create(:country, iso: 'DE', name: 'Germany') }
      let!(:eu_market) { create(:market, store: store, name: 'Europe', default_locale: 'de', currency: 'EUR', countries: [germany]) }

      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en de fr])
        allow(store).to receive(:supported_currencies_list).and_return(
          [Money::Currency.find('USD'), Money::Currency.find('EUR')]
        )
      end

      it 'uses market default locale when no explicit locale is provided' do
        request.headers['x-spree-country'] = 'DE'
        get :index

        expect(I18n.locale).to eq(:de)
        expect(controller.send(:current_locale)).to eq('de')
      end

      it 'uses market currency when no explicit currency is provided' do
        request.headers['x-spree-country'] = 'DE'
        get :index

        expect(controller.send(:current_currency)).to eq('EUR')
      end

      it 'explicit locale header overrides market default locale' do
        request.headers['x-spree-country'] = 'DE'
        request.headers['x-spree-locale'] = 'fr'
        get :index

        expect(I18n.locale).to eq(:fr)
        expect(controller.send(:current_locale)).to eq('fr')
      end

      it 'explicit currency header overrides market currency' do
        request.headers['x-spree-country'] = 'DE'
        request.headers['x-spree-currency'] = 'USD'
        get :index

        expect(controller.send(:current_currency)).to eq('USD')
      end
    end
  end
end
