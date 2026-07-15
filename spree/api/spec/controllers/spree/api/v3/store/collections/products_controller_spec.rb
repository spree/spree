require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Collections::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:collection) { create(:collection, store: store) }
  let!(:in_product) { create(:product, status: 'active') }
  let!(:out_product) { create(:product, status: 'active') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    Spree::ProductCollection.create!(collection: collection, product: in_product)
  end

  describe 'GET #index' do
    it 'returns only products in the collection' do
      get :index, params: { collection_id: collection.prefixed_id }

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].pluck('id')
      expect(ids).to include(in_product.prefixed_id)
      expect(ids).not_to include(out_product.prefixed_id)
    end

    it 'resolves the collection by permalink' do
      get :index, params: { collection_id: collection.permalink }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to include(in_product.prefixed_id)
    end

    it 'returns not found for an unknown collection' do
      get :index, params: { collection_id: 'coll_nope' }

      expect(response).to have_http_status(:not_found)
    end

    # Mirrors Store::CollectionsController#find_resource: a permalink that only
    # exists in the default locale must still resolve the PLP on a non-default
    # locale, so the detail page and its product listing stay in sync.
    context 'locale fallback', if: Spree::Collection.include?(Spree::TranslatableResource) do
      before do
        allow(store).to receive(:supported_locales_list).and_return(%w[en fr])
        allow(store).to receive(:default_locale).and_return('en')
      end

      it 'resolves the default-locale permalink on a non-default locale' do
        request.headers['x-spree-locale'] = 'fr'
        get :index, params: { collection_id: collection.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].pluck('id')).to include(in_product.prefixed_id)
      end
    end
  end
end
