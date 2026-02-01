require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::TaxonsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_store_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = store.default_locale
  end

  describe 'GET #show' do
    context 'finding by permalink' do
      it 'returns the taxon by permalink' do
        get :show, params: { id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(taxon.prefix_id)
        expect(json_response['name']).to eq(taxon.name)
        expect(json_response['permalink']).to eq(taxon.permalink)
      end

      it 'returns nested taxon by full permalink path' do
        get :show, params: { id: child_taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(child_taxon.prefix_id)
        expect(json_response['name']).to eq(child_taxon.name)
      end
    end

    context 'finding by prefix_id' do
      it 'returns the taxon by prefix_id' do
        get :show, params: { id: taxon.prefix_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(taxon.prefix_id)
        expect(json_response['name']).to eq(taxon.name)
        expect(json_response['permalink']).to eq(taxon.permalink)
      end
    end

    it 'returns taxon attributes' do
      get :show, params: { id: taxon.permalink }

      expect(json_response).to include('id', 'name', 'permalink')
    end

    it 'includes parent information for child taxon' do
      get :show, params: { id: child_taxon.permalink }

      expect(response).to have_http_status(:ok)
      expect(json_response['parent_id']).to eq(taxon.prefix_id)
    end

    context 'with translations', if: Spree::Taxon.include?(Spree::TranslatableResource) do
      let!(:translated_taxon) do
        create(:taxon, taxonomy: taxonomy, name: 'Clothing', permalink: 'clothing').tap do |t|
          Mobility.with_locale(:fr) do
            t.name = 'Vêtements'
            t.permalink = 'vetements'
            t.save!
          end
        end
      end

      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en fr])
        allow(store).to receive(:default_locale).and_return('en')
      end

      it 'finds taxon by English permalink with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: translated_taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Clothing')
        expect(json_response['permalink']).to eq(translated_taxon.permalink)
      end

      it 'finds taxon by French permalink with French locale' do
        french_permalink = Mobility.with_locale(:fr) { translated_taxon.permalink }
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: french_permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Vêtements')
        expect(json_response['permalink']).to eq(french_permalink)
      end

      it 'returns translated content based on locale header' do
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: translated_taxon.prefix_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Vêtements')
      end

      it 'returns 404 when searching French permalink with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: 'vetements' }

        expect(response).to have_http_status(:not_found)
      end

      context 'locale fallback' do
        let!(:english_only_taxon) do
          create(:taxon, taxonomy: taxonomy, name: 'Electronics')
        end

        it 'falls back to default locale when taxon has no translation in requested locale' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: english_only_taxon.permalink }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(english_only_taxon.prefix_id)
          # Name returns English since no French translation exists
          expect(json_response['name']).to eq('Electronics')
        end

        it 'returns translated content when translation exists' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: translated_taxon.permalink }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(translated_taxon.prefix_id)
          expect(json_response['name']).to eq('Vêtements')
        end
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent taxon' do
        get :show, params: { id: 'non-existent-permalink' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for taxon from another store' do
        get :show, params: { id: other_store_taxon.permalink }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for invalid prefix_id' do
        get :show, params: { id: 'txn_invalid123' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: taxon.permalink }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
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
        get :show, params: { id: taxon.prefix_id }

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:fr)
      end

      it 'falls back to default locale for unsupported locale' do
        request.headers['x-spree-locale'] = 'de'
        get :show, params: { id: taxon.prefix_id }

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
        get :show, params: { id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('EUR')
      end

      it 'falls back to default currency for unsupported currency' do
        request.headers['x-spree-currency'] = 'GBP'
        get :show, params: { id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_currency)).to eq('USD')
      end
    end
  end
end
