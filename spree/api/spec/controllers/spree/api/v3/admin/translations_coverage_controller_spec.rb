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

    context 'with a model whose label is a different column than its name' do
      # An option type displays `label` (stored as `presentation`) while `name`
      # holds a slug, so searching `name` would mean typing the visible label
      # finds nothing.
      let!(:option_type) { create(:option_type, name: 'shirt-size', presentation: 'Shirt Size') }

      it 'searches the column the grid displays' do
        get :index, params: { resource_type: 'option_type', search: 'Shirt Size' }, as: :json

        expect(json_response['data']['search_field']).to eq('presentation_cont')
        labels = json_response['data']['records'].map { |r| r['label'] }
        expect(labels).to include('Shirt Size')
      end
    end

    context 'with a model whose whitelist omits name' do
      it 'still searches by name, which Ransack allows by default' do
        collection = create(:collection, store: store, name: 'Summer Sale')

        get :index, params: { resource_type: 'collection', search: 'Summer' }, as: :json

        expect(response).to have_http_status(:ok)
        # `whitelisted_ransackable_attributes` omits name, but the defaults
        # Ransack unions in carry it — reading only the whitelist would send
        # this grid to `permalink` and find nothing.
        expect(json_response['data']['search_field']).to eq('name_cont')
        expect(json_response['data']['records'].map { |r| r['label'] }).to eq([collection.name])
      end
    end

    context 'with a resource scoped by a polymorphic owner' do
      let!(:other_store) { create(:store) }
      let!(:mine) { create(:policy, owner: store, name: 'Shipping Policy') }
      let!(:theirs) { create(:policy, owner: other_store, name: 'Their Policy') }

      it 'excludes another store\'s records' do
        # spree_policies has no store_id column, so anything keying on the
        # column alone would hand back every store's policies.
        get :index, params: { resource_type: 'policy' }, as: :json

        expect(response).to have_http_status(:ok)
        labels = json_response['data']['records'].map { |r| r['label'] }
        expect(labels).to include('Shipping Policy')
        expect(labels).not_to include('Their Policy')
      end
    end

    context 'with a singleton resource type' do
      let!(:other_store) { create(:store, name: 'Some Other Store') }

      it 'reports only the current store, never every store in the install' do
        get :index, params: { resource_type: 'store' }, as: :json

        expect(response).to have_http_status(:ok)
        labels = json_response['data']['records'].map { |r| r['label'] }
        expect(labels).to eq([store.name])
        expect(labels).not_to include('Some Other Store')
        expect(json_response['data']['coverage'].first['total']).to eq(1)
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

    describe 'authorization' do
      # Each type is read under the permission of what it belongs to, matching
      # the per-resource translations endpoint: an option type's translations
      # ride `products`, a policy's ride `settings`.
      {
        'product' => :products,
        'category' => :categories,
        'collection' => :collections,
        'option_type' => :products,
        'policy' => :settings
      }.each do |resource_type, expected_scope|
        it "reads #{resource_type} translations under #{expected_scope}" do
          controller.params[:resource_type] = resource_type

          expect(controller.send(:scoped_resource_name)).to eq(expected_scope)
        end
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
