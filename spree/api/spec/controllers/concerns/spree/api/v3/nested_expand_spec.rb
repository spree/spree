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
      it 'expands variants with nested media' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.media' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).to have_key('media')
        end
      end

      it 'expands variants without media when only variants requested' do
        get :show, params: { id: product.prefixed_id, expand: 'variants' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).not_to have_key('media')
        end
      end

      it 'supports multiple nested expands' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.media,variants.custom_fields' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        data['variants'].each do |variant|
          expect(variant).to have_key('media')
          expect(variant).to have_key('custom_fields')
        end
      end

      it 'supports mixed top-level and nested expands' do
        get :show, params: { id: product.prefixed_id, expand: 'variants.media,option_types' }

        data = JSON.parse(response.body)
        expect(data).to have_key('variants')
        expect(data).to have_key('option_types')
        data['variants'].each do |variant|
          expect(variant).to have_key('media')
        end
      end
    end

    describe 'nested expand on aliased associations (key differs from name)' do
      let!(:taxonomy) { create(:taxonomy, store: store) }
      let!(:parent_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }
      let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: parent_taxon) }

      before do
        product.taxons << child_taxon
      end

      it 'expands categories with nested ancestors' do
        get :show, params: { id: product.prefixed_id, expand: 'categories.ancestors' }

        data = JSON.parse(response.body)
        expect(data).to have_key('categories')
        expect(data['categories']).to be_an(Array)
        data['categories'].each do |category|
          expect(category).to have_key('ancestors')
          expect(category['ancestors']).to be_an(Array)
        end
      end

      it 'expands categories without ancestors when only categories requested' do
        get :show, params: { id: product.prefixed_id, expand: 'categories' }

        data = JSON.parse(response.body)
        expect(data).to have_key('categories')
        data['categories'].each do |category|
          expect(category).not_to have_key('ancestors')
        end
      end
    end

    describe 'collection endpoint' do
      it 'supports nested expand on index' do
        get :index, params: { expand: 'variants.media' }

        data = JSON.parse(response.body)['data']
        data.each do |product|
          expect(product).to have_key('variants')
          product['variants'].each do |variant|
            expect(variant).to have_key('media')
          end
        end
      end
    end
  end
end
