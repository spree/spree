require 'spec_helper'

describe 'Storefront API v2 Stores spec', type: :request do
  let(:store) { @default_store }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::StoresController).to receive(:current_store).and_return(store)
  end

  describe 'stores#show' do
    context 'with code param' do
      before { get "/api/v2/storefront/stores/#{store.code}" }

      it 'return store with attributes' do
        expect(json_response['data']).to have_attribute(:name).with_value(store.name)
        expect(json_response['data']).to have_attribute(:url).with_value(store.url)
        expect(json_response['data']).to have_attribute(:meta_description).with_value(store.meta_description)
        expect(json_response['data']).to have_attribute(:meta_keywords).with_value(store.meta_keywords)
        expect(json_response['data']).to have_attribute(:seo_title).with_value(store.seo_title)
        expect(json_response['data']).to have_attribute(:default_currency).with_value(store.default_currency)
        expect(json_response['data']).to have_attribute(:default).with_value(store.default)
        expect(json_response['data']).to have_attribute(:supported_currencies).with_value(store.supported_currencies)
        expect(json_response['data']).to have_attribute(:facebook).with_value(store.facebook)
        expect(json_response['data']).to have_attribute(:twitter).with_value(store.twitter)
        expect(json_response['data']).to have_attribute(:instagram).with_value(store.instagram)
        expect(json_response['data']).to have_attribute(:default_locale).with_value(store.default_locale)
        expect(json_response['data']).to have_attribute(:supported_locales).with_value(store.supported_locales)
        expect(json_response['data']).to have_attribute(:description).with_value(store.description)
        expect(json_response['data']).to have_attribute(:address).with_value(store.address)
        expect(json_response['data']).to have_attribute(:contact_phone).with_value(store.contact_phone)

        expect(json_response['data']).to have_relationship(:default_country)
        expect(json_response['data']).to have_relationship(:default_country).with_data('id' => store.default_country_id.to_s, 'type' => 'country')
      end

      describe 'favicon_path attribute' do
        context 'with favicon attached' do
          let!(:store) { create(:store, :with_favicon) }

          it 'returns store favicon path' do
            expect(json_response.dig(:data, :attributes, :favicon_path)).to end_with('thinking-cat.jpg')
          end
        end
      end
    end

    context 'with locale set to pl' do
      let!(:store) do
        localized_store = create(:store, default_country: create(:country))
        localized_store.supported_locales = 'en,pl'
        localized_store.save

        Mobility.with_locale(:pl) do
          localized_store.update(
            name: 'Test Store PL',
            meta_description: 'Meta Desc PL',
            meta_keywords: 'meta, keywords, pl',
            seo_title: 'SEO Title PL'
          )
        end

        localized_store
      end

      before do
        get "/api/v2/storefront/stores/#{store.code}?locale=pl"
      end

      after do
        I18n.locale = :en
        store.update!(supported_locales: 'en')
      end

      it 'return store with translated attributes' do
        expect(json_response['data']).to have_attribute(:name).with_value('Test Store PL')
        expect(json_response['data']).to have_attribute(:meta_description).with_value('Meta Desc PL')
        expect(json_response['data']).to have_attribute(:meta_keywords).with_value('meta, keywords, pl')
        expect(json_response['data']).to have_attribute(:seo_title).with_value('SEO Title PL')
      end
    end

    context 'with invalid code param' do
      before { get '/api/v2/storefront/stores/XX' }

      it 'return error' do
        expect(json_response['error']).to eq('The resource you were looking for could not be found.')
      end
    end

    describe 'stores#current_store' do
      before do
        get "/api/v2/storefront/store"
      end

      it 'returns store with attributes' do
        expect(json_response['data']).to have_attribute(:name).with_value(store.name)
        expect(json_response['data']).to have_attribute(:url).with_value(store.url)
        expect(json_response['data']).to have_attribute(:meta_description).with_value(store.meta_description)
        expect(json_response['data']).to have_attribute(:meta_keywords).with_value(store.meta_keywords)
        expect(json_response['data']).to have_attribute(:seo_title).with_value(store.seo_title)
        expect(json_response['data']).to have_attribute(:default_currency).with_value(store.default_currency)
        expect(json_response['data']).to have_attribute(:default).with_value(store.default)
        expect(json_response['data']).to have_attribute(:supported_currencies).with_value(store.supported_currencies)
        expect(json_response['data']).to have_attribute(:facebook).with_value(store.facebook)
        expect(json_response['data']).to have_attribute(:twitter).with_value(store.twitter)
        expect(json_response['data']).to have_attribute(:instagram).with_value(store.instagram)
        expect(json_response['data']).to have_attribute(:default_locale).with_value(store.default_locale)
        expect(json_response['data']).to have_attribute(:supported_locales).with_value(store.supported_locales)
        expect(json_response['data']).to have_attribute(:description).with_value(store.description)
        expect(json_response['data']).to have_attribute(:address).with_value(store.address)
        expect(json_response['data']).to have_attribute(:contact_phone).with_value(store.contact_phone)

        expect(json_response['data']).to have_relationship(:default_country)
        expect(json_response['data']).to have_relationship(:default_country).with_data('id' => store.default_country_id.to_s, 'type' => 'country')
      end
    end
  end
end
