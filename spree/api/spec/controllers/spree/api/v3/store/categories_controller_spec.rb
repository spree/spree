require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CategoriesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon) }
  let!(:grandchild_taxon) { create(:taxon, taxonomy: taxonomy, parent: child_taxon) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_store_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = store.default_locale
  end

  describe 'GET #index' do
    it 'returns categories for the current store' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to include(taxon.prefixed_id, child_taxon.prefixed_id)
      expect(json_response['data'].pluck('id')).not_to include(other_store_taxon.prefixed_id)
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    it 'returns category attributes' do
      get :index

      category_data = json_response['data'].find { |t| t['id'] == taxon.prefixed_id }
      expect(category_data).to include('name', 'permalink', 'position', 'depth')
      expect(category_data).to include('parent_id', 'children_count')
      expect(category_data).not_to include('lft', 'rgt')
    end

    context 'with images' do
      let!(:taxon_with_image) { create(:taxon, :with_header_image, taxonomy: taxonomy) }

      it 'returns image URLs' do
        get :index

        category_data = json_response['data'].find { |t| t['id'] == taxon_with_image.prefixed_id }
        expect(category_data['image_url']).to be_present
      end
    end

    context 'filtering' do
      it 'filters by depth' do
        get :index, params: { q: { depth_eq: grandchild_taxon.depth } }

        ids = json_response['data'].pluck('id')
        expect(ids).to include(grandchild_taxon.prefixed_id)
      end

      it 'filters by parent_id' do
        get :index, params: { q: { parent_id_eq: child_taxon.id } }

        ids = json_response['data'].pluck('id')
        expect(ids).to include(grandchild_taxon.prefixed_id)
      end
    end

    context 'sorting' do
      let!(:taxon_b) { create(:taxon, taxonomy: taxonomy, name: 'Bags') }
      let!(:taxon_z) { create(:taxon, taxonomy: taxonomy, name: 'Zippers') }

      it 'sorts by name ascending' do
        get :index, params: { sort: 'name' }

        expect(response).to have_http_status(:ok)
        names = json_response['data'].map { |t| t['name'] }
        bags_index = names.index('Bags')
        zippers_index = names.index('Zippers')
        expect(bags_index).to be < zippers_index
      end

      it 'sorts by name descending' do
        get :index, params: { sort: '-name' }

        expect(response).to have_http_status(:ok)
        names = json_response['data'].map { |t| t['name'] }
        bags_index = names.index('Bags')
        zippers_index = names.index('Zippers')
        expect(zippers_index).to be < bags_index
      end
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
    context 'finding by permalink' do
      it 'returns the category by permalink' do
        get :show, params: { id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(taxon.prefixed_id)
        expect(json_response['name']).to eq(taxon.name)
        expect(json_response['permalink']).to eq(taxon.permalink)
      end

      it 'returns nested category by full permalink path' do
        get :show, params: { id: child_taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(child_taxon.prefixed_id)
        expect(json_response['name']).to eq(child_taxon.name)
      end
    end

    context 'finding by prefix_id' do
      it 'returns the category by prefix_id' do
        get :show, params: { id: taxon.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(taxon.prefixed_id)
        expect(json_response['name']).to eq(taxon.name)
        expect(json_response['permalink']).to eq(taxon.permalink)
      end
    end

    it 'returns category attributes' do
      get :show, params: { id: taxon.permalink }

      expect(json_response).to include('id', 'name', 'permalink')
    end

    it 'includes parent information for child category' do
      get :show, params: { id: child_taxon.permalink }

      expect(response).to have_http_status(:ok)
      expect(json_response['parent_id']).to eq(taxon.prefixed_id)
    end

    it 'does not include lft and rgt in store API' do
      get :show, params: { id: taxon.prefixed_id }

      expect(json_response).not_to include('lft', 'rgt')
    end

    context 'with expand=ancestors' do
      it 'returns ancestors for breadcrumbs' do
        get :show, params: { id: grandchild_taxon.prefixed_id, expand: 'ancestors' }

        expect(response).to have_http_status(:ok)
        expect(json_response['ancestors']).to be_an(Array)
        ancestor_ids = json_response['ancestors'].pluck('id')
        expect(ancestor_ids).to include(taxon.prefixed_id, child_taxon.prefixed_id)
      end

      it 'returns empty ancestors for root category' do
        root_taxon = taxonomy.root

        get :show, params: { id: root_taxon.prefixed_id, expand: 'ancestors' }

        expect(response).to have_http_status(:ok)
        expect(json_response['ancestors']).to eq([])
      end
    end

    context 'with expand=children' do
      it 'returns children' do
        get :show, params: { id: taxon.prefixed_id, expand: 'children' }

        expect(response).to have_http_status(:ok)
        expect(json_response['children']).to be_an(Array)
        expect(json_response['children'].pluck('id')).to include(child_taxon.prefixed_id)
      end
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

      it 'finds category by English permalink with English locale' do
        request.headers['x-spree-locale'] = 'en'
        get :show, params: { id: translated_taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Clothing')
        expect(json_response['permalink']).to eq(translated_taxon.permalink)
      end

      it 'finds category by French permalink with French locale' do
        french_permalink = Mobility.with_locale(:fr) { translated_taxon.permalink }
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: french_permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq('Vêtements')
        expect(json_response['permalink']).to eq(french_permalink)
      end

      it 'returns translated content based on locale header' do
        request.headers['x-spree-locale'] = 'fr'
        get :show, params: { id: translated_taxon.prefixed_id }

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

        it 'falls back to default locale when category has no translation in requested locale' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: english_only_taxon.permalink }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(english_only_taxon.prefixed_id)
          expect(json_response['name']).to eq('Electronics')
        end

        it 'returns translated content when translation exists' do
          request.headers['x-spree-locale'] = 'fr'
          get :show, params: { id: translated_taxon.permalink }

          expect(response).to have_http_status(:ok)
          expect(json_response['id']).to eq(translated_taxon.prefixed_id)
          expect(json_response['name']).to eq('Vêtements')
        end
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent category' do
        get :show, params: { id: 'non-existent-permalink' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for category from another store' do
        get :show, params: { id: other_store_taxon.permalink }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for invalid prefix_id' do
        get :show, params: { id: 'ctg_invalid123' }

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
        get :show, params: { id: taxon.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(I18n.locale).to eq(:fr)
      end

      it 'falls back to default locale for unsupported locale' do
        request.headers['x-spree-locale'] = 'de'
        get :show, params: { id: taxon.prefixed_id }

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
