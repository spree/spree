require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TagsController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    context 'authenticated as an admin (JWT)' do
      let(:headers) { bearer_headers }

      let!(:tagged_product) { create(:product, store: store, tag_list: ['summer']) }

      it 'returns matching tag names for the type' do
        get :index, params: { taggable_type: 'Spree::Product' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |t| t['name'] }).to include('summer')
      end

      it 'rejects an unregistered taggable type' do
        get :index, params: { taggable_type: 'Spree::Secret' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'order tag vocabulary is store-scoped' do
      let(:headers) { bearer_headers }

      let(:other_store) { create(:store) }
      let!(:own_order) { create(:order, store: store, tag_list: ['vip']) }
      let!(:foreign_order) { create(:order, store: other_store, tag_list: ['fraud-watch']) }

      it 'excludes another store\'s order tags' do
        get :index, params: { taggable_type: 'Spree::Order' }, as: :json

        names = json_response['data'].map { |t| t['name'] }
        expect(names).to include('vip')
        expect(names).not_to include('fraud-watch')
      end
    end

    context 'product tag vocabulary is store-scoped' do
      let(:headers) { bearer_headers }

      let(:other_store) { create(:store) }
      let!(:own_product) { create(:product, store: store, tag_list: ['bestseller']) }
      let!(:foreign_product) { create(:product, store: other_store, tag_list: ['clearance']) }

      it 'excludes another store\'s product tags' do
        get :index, params: { taggable_type: 'Spree::Product' }, as: :json

        names = json_response['data'].map { |t| t['name'] }
        expect(names).to include('bestseller')
        expect(names).not_to include('clearance')
      end
    end

    describe 'API-key scope enforcement' do
      let(:headers) { { 'x-spree-api-key' => api_key.plaintext_token } }
      let!(:tagged_user) { create(:user, tag_list: ['vip']) }

      context 'with a key lacking read_customers' do
        let(:api_key) { create(:api_key, :secret, store: store, scopes: ['read_products']) }

        it 'forbids listing customer tags' do
          get :index, params: { taggable_type: Spree.user_class.to_s }, as: :json

          expect(response).to have_http_status(:forbidden)
          expect(json_response['error']['details']['required_scope']).to eq('read_customers')
        end
      end

      context 'with a key holding read_customers' do
        let(:api_key) { create(:api_key, :secret, store: store, scopes: ['read_customers']) }

        it 'allows listing customer tags' do
          get :index, params: { taggable_type: Spree.user_class.to_s }, as: :json

          expect(response).to have_http_status(:ok)
          expect(json_response['data'].map { |t| t['name'] }).to include('vip')
        end
      end
    end
  end
end
