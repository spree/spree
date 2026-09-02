require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TranslationsCoverageController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { @default_store }

  before do
    configure_supported_locales(store, %w[en de fr])
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    let!(:translated) { create(:product, store: store, name: 'Espresso Machine') }
    let!(:untranslated) { create(:product, store: store, name: 'Drip Coffee Maker') }

    # Every translatable field filled in for German, so the record counts as
    # fully covered; only one field for French, so it counts as partial.
    before do
      Mobility.with_locale(:de) do
        translated.update!(
          name: 'Espressomaschine',
          description: '<p>Zieht einen guten Shot.</p>',
          slug: 'espressomaschine',
          meta_title: 'Espressomaschine',
          meta_description: 'Kaufen Sie die Espressomaschine.'
        )
      end
      Mobility.with_locale(:fr) { translated.update!(name: 'Machine à espresso') }
    end

    it 'reports the store locales without the default one' do
      get :index, params: { resource_type: 'product' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['locales']).to eq(%w[de fr])
      expect(json_response['data']['default_locale']).to eq('en')
      expect(json_response['data']['resource_type']).to eq('product')
    end

    it 'counts a record as covered only when every field is translated' do
      get :index, params: { resource_type: 'product' }, as: :json

      coverage = json_response['data']['coverage'].index_by { |row| row['locale'] }

      expect(coverage['de']['translated']).to eq(1)
      expect(coverage['de']['total']).to eq(2)
      expect(coverage['de']['coverage']).to eq(0.5)

      # The French translation covers name only, so it is not counted.
      expect(coverage['fr']['translated']).to eq(0)
      expect(coverage['fr']['coverage']).to eq(0.0)
    end

    it 'returns the per-record translated field count for each locale' do
      get :index, params: { resource_type: 'product' }, as: :json

      records = json_response['data']['records'].index_by { |r| r['label'] }

      # French carries name plus the slug derived from it — two of five fields.
      expect(records['Espresso Machine']['locales']).to eq('de' => 5, 'fr' => 2)
      expect(records['Drip Coffee Maker']['locales']).to eq('de' => 0, 'fr' => 0)
      expect(json_response['data']['field_count']).to eq(5)
    end

    it 'labels records in the default locale, not the request locale' do
      request.headers['x-spree-locale'] = 'de'

      get :index, params: { resource_type: 'product' }, as: :json

      labels = json_response['data']['records'].map { |r| r['label'] }
      expect(labels).to include('Espresso Machine')
      expect(labels).not_to include('Espressomaschine')
    end

    it 'returns prefixed ids so a row can deep-link to its editor' do
      get :index, params: { resource_type: 'product' }, as: :json

      ids = json_response['data']['records'].map { |r| r['id'] }
      expect(ids).to all(start_with('prod_'))
    end

    it 'paginates' do
      get :index, params: { resource_type: 'product', limit: 1 }, as: :json

      expect(json_response['data']['records'].size).to eq(1)
      expect(json_response['meta']['count']).to eq(2)
      expect(json_response['meta']['pages']).to eq(2)
    end

    it 'filters through ransack' do
      get :index, params: { resource_type: 'product', q: { name_cont: 'Espresso' } }, as: :json

      labels = json_response['data']['records'].map { |r| r['label'] }
      expect(labels).to eq(['Espresso Machine'])
    end

    it 'applies a plain search term through the whitelisted predicate' do
      get :index, params: { resource_type: 'product', search: 'Espresso' }, as: :json

      labels = json_response['data']['records'].map { |r| r['label'] }
      expect(labels).to eq(['Espresso Machine'])
    end

    it 'reports which predicate the grid can filter by' do
      get :index, params: { resource_type: 'product' }, as: :json

      expect(json_response['data']['search_field']).to eq('name_cont')
    end

    context 'with a model that does not whitelist name' do
      it 'falls back to a predicate the model does whitelist' do
        get :index, params: { resource_type: 'collection' }, as: :json

        expect(response).to have_http_status(:ok)
        # Collection whitelists permalink but not name, so the grid is told to
        # search that instead of a predicate Ransack would reject.
        expect(json_response['data']['search_field']).to eq('permalink_cont')
      end
    end

    context 'with another resource type' do
      let!(:option_type) { create(:option_type, name: 'color', presentation: 'Color') }

      it 'reports coverage using the public field name' do
        Mobility.with_locale(:de) { option_type.update!(presentation: 'Farbe') }

        get :index, params: { resource_type: 'option_type' }, as: :json

        expect(json_response['data']['field_count']).to eq(1)
        record = json_response['data']['records'].find { |r| r['label'] == 'Color' }
        expect(record['locales']).to eq('de' => 1, 'fr' => 0)
      end
    end

    context 'when the store has no non-default locales' do
      before { configure_supported_locales(store, %w[en]) }

      it 'returns empty locales and coverage' do
        get :index, params: { resource_type: 'product' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['locales']).to eq([])
        expect(json_response['data']['coverage']).to eq([])
        expect(json_response['data']['records'].first['locales']).to eq({})
      end
    end

    context 'with an unknown resource type' do
      it 'returns 404' do
        get :index, params: { resource_type: 'nonsense' }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a resource type that is not translatable' do
      it 'returns 404' do
        get :index, params: { resource_type: 'order' }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with another store\'s records' do
      let(:other_store) { create(:store) }
      let!(:other_product) { create(:product, store: other_store, name: 'Not Mine') }

      it 'excludes them' do
        get :index, params: { resource_type: 'product' }, as: :json

        labels = json_response['data']['records'].map { |r| r['label'] }
        expect(labels).not_to include('Not Mine')
        expect(json_response['data']['coverage'].first['total']).to eq(2)
      end
    end
  end
end
