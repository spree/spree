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

      before do
        # Write directly to the translations table to avoid Mobility column_fallback
        # interfering when I18n.locale is leaked by other tests
        Spree::Product::Translation.create!(spree_product_id: product1.id, locale: 'de', name: 'Widget DE', description: 'Beschreibung')
        Spree::Product::Translation.create!(spree_product_id: product1.id, locale: 'fr', name: 'Widget FR')
      end

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

      it 'assigns coverage data for each locale' do
        index

        coverage = assigns[:coverage]
        expect(coverage.size).to eq(2)

        de_coverage = coverage.find { |c| c[:locale] == 'de' }
        expect(de_coverage[:translated]).to eq(1)
        expect(de_coverage[:total]).to eq(2)
        expect(de_coverage[:percentage]).to eq(50)

        fr_coverage = coverage.find { |c| c[:locale] == 'fr' }
        expect(fr_coverage[:translated]).to eq(1)
        expect(fr_coverage[:total]).to eq(2)
        expect(fr_coverage[:percentage]).to eq(50)
      end

      it 'assigns products' do
        index
        expect(assigns[:products]).to contain_exactly(product1, product2)
      end

      it 'assigns the translated locales map' do
        index

        map = assigns[:translated_locales_map]
        expect(map[product1.id]).to contain_exactly('de', 'fr')
        expect(map[product2.id]).to be_nil
      end

      it 'displays product names in the response' do
        index
        expect(response.body).to include('Widget')
        expect(response.body).to include('Gadget')
      end

      it 'displays the coverage table' do
        index
        expect(response.body).to include('50%')
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
