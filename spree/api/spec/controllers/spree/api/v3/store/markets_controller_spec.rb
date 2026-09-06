require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:usa) { Spree::Country.by_iso('US') }
  let!(:germany) { Spree::Country.by_iso('DE') }
  let!(:france) { Spree::Country.by_iso('FR') }

  # The store's bootstrap market already owns the US country — reshape it
  # into the North America fixture instead of colliding with it.
  let!(:na_market) do
    store.default_market.tap do |market|
      market.update!(name: 'North America', currency: 'USD', default_locale: 'en', supported_locales: 'en,es')
    end
  end
  let!(:eu_market) { create(:market, name: 'Europe', store: store, countries: [germany, france], currency: 'EUR', default_locale: 'de', supported_locales: 'de,en,fr', tax_inclusive: true) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns all markets for the store' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
    end

    it 'returns market attributes' do
      get :index

      na = json_response['data'].find { |m| m['name'] == 'North America' }
      expect(na['id']).to eq(na_market.prefixed_id)
      expect(na['currency']).to eq('USD')
      expect(na['default_locale']).to eq('en')
      expect(na['supported_locales']).to match_array(['en', 'es'])
      expect(na['tax_inclusive']).to eq(false)
      expect(na['default']).to eq(true)
    end

    it 'includes nested countries' do
      get :index

      eu = json_response['data'].find { |m| m['name'] == 'Europe' }
      expect(eu['countries'].size).to eq(2)
      isos = eu['countries'].map { |c| c['iso'] }
      expect(isos).to match_array(['DE', 'FR'])
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns a market by prefixed ID' do
      get :show, params: { id: eu_market.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
      expect(json_response['name']).to eq('Europe')
      expect(json_response['currency']).to eq('EUR')
      expect(json_response['tax_inclusive']).to eq(true)
      expect(json_response['countries'].size).to eq(2)
    end

    it 'returns 404 for non-existent market' do
      get :show, params: { id: 'mkt_nonexistent' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #resolve' do
    it 'resolves a market by country ISO' do
      get :resolve, params: { country: 'DE' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
      expect(json_response['name']).to eq('Europe')
      expect(json_response['currency']).to eq('EUR')
    end

    it 'is case-insensitive for country ISO' do
      get :resolve, params: { country: 'de' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(eu_market.prefixed_id)
    end

    it 'returns 404 for a country not in any market' do
      create(:country, iso: 'JP', name: 'Japan')
      get :resolve, params: { country: 'JP' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for an invalid country ISO' do
      get :resolve, params: { country: 'XX' }

      expect(response).to have_http_status(:not_found)
    end
  end

  # docs/plans/6.0-channel-markets.md — an allowlist narrows what the
  # storefront may see; no allowlist leaves every market visible.
  describe 'channel market allowlist' do
    let!(:channel) { create(:channel, store: store, code: 'wholesale') }

    before { request.headers['X-Spree-Channel'] = 'wholesale' }

    context 'when the channel serves every market' do
      it 'lists them all' do
        get :index

        names = json_response['data'].map { |market| market['name'] }
        expect(names).to include('North America', 'Europe')
      end
    end

    context 'when the channel is narrowed' do
      before { channel.markets << eu_market }

      it 'lists only the served markets' do
        get :index

        names = json_response['data'].map { |market| market['name'] }
        expect(names).to contain_exactly('Europe')
      end

      it '404s an unserved market by id' do
        get :show, params: { id: na_market.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end

      it 'still shows a served market by id' do
        get :show, params: { id: eu_market.prefixed_id }

        expect(response).to have_http_status(:ok)
      end

      # The resolve action reaches market_for_country directly, so it needs
      # its own guard — the 404 is indistinguishable from "no market here".
      it '404s resolving a country whose market the channel does not serve' do
        get :resolve, params: { country: 'US' }

        expect(response).to have_http_status(:not_found)
      end

      it 'still resolves a served country' do
        get :resolve, params: { country: 'DE' }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Europe')
      end

      # Currency and locale derive from the resolved market, and their
      # callbacks run before the channel one. Rejecting an unserved market
      # therefore has to write the channel's own default rather than fall
      # through to Spree::Current, whose channel is still the store default
      # at that point — otherwise a narrowed channel prices in the wrong
      # currency (docs/plans/6.0-channel-markets.md).
      it 'puts a shopper from an unserved country on the channel default market' do
        seen = nil
        allow(Spree.api.market_serializer).to receive(:new).and_wrap_original do |original, *args, **kwargs|
          seen ||= [Spree::Current.market, Spree::Current.currency]
          original.call(*args, **kwargs)
        end

        request.headers['x-spree-country'] = 'US'
        get :index

        expect(seen.first).to eq(eu_market)
        expect(seen.last).to eq('EUR')
      end

      # Most storefront requests carry no country header at all. The channel
      # default has to apply to those too — currency freezes at set_currency,
      # several callbacks before the channel resolves, so a callback that
      # returned early on a missing header left the shopper on the store's
      # currency while the market said otherwise.
      it 'applies the channel default market when no country header is sent' do
        seen = nil
        allow(Spree.api.market_serializer).to receive(:new).and_wrap_original do |original, *args, **kwargs|
          seen ||= [Spree::Current.market, Spree::Current.currency]
          original.call(*args, **kwargs)
        end

        get :index

        expect(seen.first).to eq(eu_market)
        expect(seen.last).to eq('EUR')
      end

      # The channel's markets are the sellable set, so a currency header for a
      # market it does not serve is not on offer and must be refused rather
      # than accepted as the request currency.
      it 'refuses a currency header outside the channel markets' do
        request.headers['x-spree-currency'] = 'USD'
        get :index

        expect(controller.send(:supported_currency?, 'USD')).to be false
        expect(controller.send(:supported_currency?, 'EUR')).to be true
      end
    end
  end
end
