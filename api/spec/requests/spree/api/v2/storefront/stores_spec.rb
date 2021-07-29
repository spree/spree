require 'spec_helper'

describe 'Storefront API v2 Stores spec', type: :request do
  let!(:store) { create(:store, default_country: create(:country)) }

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
            expect(json_response.dig(:data, :attributes, :favicon_path)).to end_with('favicon.ico')
          end
        end

        context 'with no favicon attached' do
          it { expect(json_response['data']).to have_attribute(:favicon_path).with_value(nil) }
        end
      end
    end

    context 'with invalid code param' do
      before { get '/api/v2/storefront/stores/XX' }

      it 'return error' do
        expect(json_response['error']).to eq('The resource you were looking for could not be found.')
      end
    end
  end
end
