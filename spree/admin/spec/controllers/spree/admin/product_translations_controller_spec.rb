require 'spec_helper'

RSpec.describe Spree::Admin::ProductTranslationsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    context 'when store has multiple locales' do
      let!(:us_market) do
        create(:market, store: store, name: 'US', currency: 'USD',
               default_locale: 'en', default: true)
      end
      let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
      let!(:eu_market) do
        create(:market, store: store, name: 'Europe', currency: 'EUR',
               default_locale: 'de', supported_locales: 'de,fr',
               countries: [de_country])
      end

      let!(:product1) { create(:product, name: 'Widget', stores: [store]) }
      let!(:product2) { create(:product, name: 'Gadget', stores: [store]) }

      it 'renders the index template' do
        index
        expect(response).to render_template(:index)
      end

      it 'returns a successful response' do
        index
        expect(response).to have_http_status(:ok)
      end

      it 'assigns locales excluding the default' do
        index
        expect(assigns[:locales]).to include('de', 'fr')
        expect(assigns[:locales]).not_to include('en')
      end

      it 'assigns coverage with correct structure' do
        index

        coverage = assigns[:coverage]
        expect(coverage.size).to eq(2)
        expect(coverage.map { |c| c[:locale] }).to contain_exactly('de', 'fr')

        coverage.each do |c|
          expect(c).to have_key(:translated)
          expect(c).to have_key(:total)
          expect(c).to have_key(:percentage)
          expect(c[:total]).to eq(2)
        end
      end

      it 'assigns products' do
        index
        expect(assigns[:products]).to contain_exactly(product1, product2)
      end

      it 'assigns translated_locales_map as a hash' do
        index
        expect(assigns[:translated_locales_map]).to be_a(Hash)
      end

      it 'displays product names in the response' do
        index
        expect(response.body).to include('Widget')
        expect(response.body).to include('Gadget')
      end

      it 'displays the coverage table' do
        index
        expect(response.body).to include('Translation coverage')
      end

      it 'includes import button' do
        index
        expect(response.body).to include('table-import')
      end

      it 'includes export modal' do
        index
        expect(response.body).to include('export-dialog')
      end
    end

    context 'when store has no additional locales' do
      it 'renders the empty state' do
        index
        expect(response).to have_http_status(:ok)
        expect(assigns[:locales]).to be_empty
      end
    end

    context 'with pagination' do
      let(:de_country) { create(:country, iso: 'DE', name: 'Germany') }
      let!(:eu_market) do
        create(:market, store: store, name: 'Europe', currency: 'EUR',
               default_locale: 'de', countries: [de_country])
      end

      before do
        30.times { |i| create(:product, name: "Product #{i.to_s.rjust(2, '0')}", stores: [store]) }
      end

      it 'paginates results' do
        get :index, params: { per_page: 10 }

        expect(assigns[:products].size).to eq(10)
        expect(assigns[:pagy]).to be_present
        expect(assigns[:pagy].pages).to eq(3)
      end
    end
  end
end
