require 'spec_helper'

module Spree
  describe Api::V1::TaxonomiesController, type: :controller do
    render_views

    let(:taxonomy) { create(:taxonomy) }
    let(:taxon) { create(:taxon, name: 'Ruby', taxonomy: taxonomy) }
    let(:taxon2) { create(:taxon, name: 'Rails', taxonomy: taxonomy) }
    let(:attributes) { [:id, :name] }

    before do
      stub_authentication!
      taxon2.children << create(:taxon, name: '3.2.2', taxonomy: taxonomy)
      taxon.children << taxon2
      taxonomy.root.children << taxon
    end

    context 'as a normal user' do
      it 'gets all taxonomies' do
        api_get :index

        expect(json_response['taxonomies'].first['name']).to eq taxonomy.name
        expect(json_response['taxonomies'].first['root']['taxons'].count).to eq 1
      end

      it 'can control the page size through a parameter' do
        create(:taxonomy)
        api_get :index, per_page: 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(2)
      end

      it 'can query the results through a paramter' do
        expected_result = create(:taxonomy, name: 'Style')
        api_get :index, q: { name_cont: 'style' }
        expect(json_response['count']).to eq(1)
        expect(json_response['taxonomies'].first['name']).to eq expected_result.name
      end

      it 'gets a single taxonomy' do
        api_get :show, id: taxonomy.id

        expect(json_response['name']).to eq taxonomy.name

        children = json_response['root']['taxons']
        expect(children.count).to eq 1
        expect(children.first['name']).to eq taxon.name
        expect(children.first.key?('taxons')).to be false
      end

      it 'gets a single taxonomy with set=nested' do
        api_get :show, id: taxonomy.id, set: 'nested'

        expect(json_response['name']).to eq taxonomy.name

        children = json_response['root']['taxons']
        expect(children.first.key?('taxons')).to be true
      end

      it 'gets the jstree-friendly version of a taxonomy' do
        api_get :jstree, id: taxonomy.id
        expect(json_response['data']).to eq(taxonomy.root.name)
        expect(json_response['attr']).to eq('id' => taxonomy.root.id, 'name' => taxonomy.root.name)
        expect(json_response['state']).to eq('closed')
      end

      it 'can learn how to create a new taxonomy' do
        api_get :new
        expect(json_response['attributes']).to eq(attributes.map(&:to_s))
        required_attributes = json_response['required_attributes']
        expect(required_attributes).to include('name')
      end

      it 'cannot create a new taxonomy if not an admin' do
        api_post :create, taxonomy: { name: 'Location' }
        assert_unauthorized!
      end

      it 'cannot update a taxonomy' do
        api_put :update, id: taxonomy.id, taxonomy: { name: 'I hacked your store!' }
        assert_unauthorized!
      end

      it 'cannot delete a taxonomy' do
        api_delete :destroy, id: taxonomy.id
        assert_unauthorized!
      end
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create' do
        api_post :create, taxonomy: { name: 'Colors' }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
      end

      it 'cannot create a new taxonomy with invalid attributes' do
        api_post :create, taxonomy: {}
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Invalid resource. Please fix errors and try again.')
      end

      it 'can destroy' do
        api_delete :destroy, id: taxonomy.id
        expect(response.status).to eq(204)
      end
    end
  end
end
