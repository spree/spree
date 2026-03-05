require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::ResourceSerializer field selection' do
    describe 'GET #index' do
      it 'returns only requested fields plus id' do
        get :index, params: { fields: 'name,slug' }

        data = JSON.parse(response.body)['data']
        data.each do |item|
          expect(item.keys).to contain_exactly('id', 'name', 'slug')
        end
      end

      it 'returns all fields when fields param is absent' do
        get :index

        data = JSON.parse(response.body)['data']
        expect(data.first.keys).to include('id', 'name', 'slug', 'description')
      end
    end

    describe 'GET #show' do
      it 'returns only requested fields plus id' do
        get :show, params: { id: product.prefixed_id, fields: 'name,slug' }

        data = JSON.parse(response.body)
        expect(data.keys).to contain_exactly('id', 'name', 'slug')
      end

      it 'always includes id even when not requested' do
        get :show, params: { id: product.prefixed_id, fields: 'name' }

        data = JSON.parse(response.body)
        expect(data).to have_key('id')
        expect(data.keys).to contain_exactly('id', 'name')
      end

      it 'returns all fields when fields param is absent' do
        get :show, params: { id: product.prefixed_id }

        data = JSON.parse(response.body)
        expect(data.keys).to include('id', 'name', 'slug', 'description')
      end
    end

    describe 'fields with expand' do
      it 'includes expanded associations when listed in fields' do
        get :show, params: {
          id: product.prefixed_id,
          fields: 'name,variants',
          expand: 'variants'
        }

        data = JSON.parse(response.body)
        expect(data.keys).to contain_exactly('id', 'name', 'variants')
        expect(data['variants']).to be_an(Array)
      end

      it 'excludes expanded associations when not listed in fields' do
        get :show, params: {
          id: product.prefixed_id,
          fields: 'name',
          expand: 'variants'
        }

        data = JSON.parse(response.body)
        expect(data.keys).to contain_exactly('id', 'name')
        expect(data).not_to have_key('variants')
      end
    end
  end
end
