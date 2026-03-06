require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'nested expand (dot notation)' do
    describe 'single level expand still works' do
      it 'expands variants' do
        get :show, params: { id: product.prefixed_id, expand: 'variants' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        expect(data['variants']).to be_an(Array)
      end

      it 'does not expand variants when not requested' do
        get :show, params: { id: product.prefixed_id }

        data = JSON.parse(response.body)
        expect(data).not_to have_key('variants')
      end
    end

    describe 'nested expand with dot notation' do
      it 'expands variants with nested images' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.images' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).to have_key('images')
        end
      end

      it 'expands variants without images when only variants requested' do
        get :show, params: { id: product.prefixed_id, expand: 'variants' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).not_to have_key('images')
        end
      end

      it 'supports multiple nested expands' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.images,variants.metafields' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).to have_key('images')
          expect(variant).to have_key('metafields')
        end
      end

      it 'supports mixed top-level and nested expands' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.images,option_types' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        expect(data).to have_key('option_types')
        data['variants'].each do |variant|
          expect(variant).to have_key('images')
        end
      end
    end

    describe 'collection endpoint' do
      it 'supports nested expand on index' do
        get :index, params: { expand: 'variants.images' }

        data = JSON.parse(response.body)['data']
        data.each do |product|
          expect(product).to have_key('variants')
          product['variants'].each do |variant|
            expect(variant).to have_key('images')
          end
        end
      end
    end
  end
end
