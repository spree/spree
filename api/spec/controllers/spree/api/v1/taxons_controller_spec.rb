require 'spec_helper'

def expect_single_taxon_result(taxon_name)
  expect(json_response['taxons'].count).to eq(1)
  expect(json_response['taxons'].first['name']).to eq(taxon_name)
end

module Spree
  describe Api::V1::TaxonsController, type: :controller do
    render_views

    let!(:taxonomy) { create(:taxonomy) }
    let!(:taxon) { create(:taxon, name: 'Ruby', taxonomy: taxonomy, parent_id: taxonomy.root.id) }
    let!(:rust_taxon) { create(:taxon, name: 'Rust', taxonomy: taxonomy, parent_id: taxonomy.root.id) }
    let!(:taxon2) { create(:taxon, name: 'Rails', taxonomy: taxonomy, parent_id: taxon.id) }
    let(:attributes) { ['id', 'name', 'pretty_name', 'permalink', 'parent_id', 'taxonomy_id', 'meta_title', 'meta_description'] }

    before do
      create(:taxon, name: 'React', taxonomy: taxonomy, parent_id: taxon2.id) # taxon3
      stub_authentication!
    end

    context 'as a normal user' do
      it 'gets all taxons for a taxonomy' do
        api_get :index, taxonomy_id: taxonomy.id
        expect(json_response['taxons'].first['name']).to eq taxon.name
        children = json_response['taxons'].first['taxons']
        expect(children.count).to eq 1
        expect(children.first['name']).to eq taxon2.name
        expect(children.first['taxons'].count).to eq 1
      end

      # Regression test for #4112
      it 'does not include children when asked not to' do
        api_get :index, taxonomy_id: taxonomy.id, without_children: 1

        expect(json_response['taxons'].first['name']).to eq(taxon.name)
        expect(json_response['taxons'].first['taxons']).to be_nil
      end

      it 'paginates through taxons' do
        new_taxon = create(:taxon, name: 'Go', taxonomy: taxonomy, parent_id: taxonomy.root.id)
        taxonomy.root.children << new_taxon
        expect(taxonomy.root.children.count).to eq(3)
        api_get :index, taxonomy_id: taxonomy.id, page: 1, per_page: 1
        expect(json_response['count']).to eq(1)
        expect(json_response['total_count']).to eq(3)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['per_page']).to eq(1)
        expect(json_response['pages']).to eq(3)
      end

      describe 'searching' do
        context 'within a taxonomy' do
          before do
            api_get :index, taxonomy_id: taxonomy.id, q: { name_cont: name }
          end

          context 'searching for top level taxon' do
            let(:name) { 'Ruby' }

            it 'returns the matching taxons' do
              expect_single_taxon_result 'Ruby'
            end
          end
        end

        context 'with a name' do
          before do
            api_get :index, q: { name_cont: name }
          end

          context 'with one result' do
            let(:name) { 'Ruby' }

            it 'returns an array including the matching taxon' do
              expect_single_taxon_result 'Ruby'
            end
          end

          context 'with no results' do
            let(:name) { 'Imaginary' }

            it 'returns an empty array of taxons' do
              expect(json_response.keys).to include('taxons')
              expect(json_response['taxons'].count).to eq(0)
            end
          end
        end

        context 'with no filters' do
          it 'gets all taxons' do
            api_get :index

            expect(json_response['taxons'].first['name']).to eq taxonomy.root.name
            children = json_response['taxons'].first['taxons']
            expect(children.count).to eq 2
            expect(children.first['name']).to eq taxon.name
            expect(children.first['taxons'].count).to eq 1
            expect(children.second['name']).to eq rust_taxon.name
            expect(children.second['taxons'].count).to eq 0
          end
        end
      end

      it 'gets a single taxon' do
        api_get :show, id: taxon.id, taxonomy_id: taxonomy.id

        expect(json_response['name']).to eq taxon.name
        expect(json_response['taxons'].count).to eq 1
      end

      it 'gets all taxons in JSTree form' do
        api_get :jstree, taxonomy_id: taxonomy.id, id: taxon.id
        response = json_response.first
        expect(response['data']).to eq(taxon2.name)
        expect(response['attr']).to eq('name' => taxon2.name, 'id' => taxon2.id)
        expect(response['state']).to eq('closed')
      end

      it 'can learn how to create a new taxon' do
        api_get :new, taxonomy_id: taxonomy.id
        expect(json_response['attributes']).to eq(attributes.map(&:to_s))
        required_attributes = json_response['required_attributes']
        expect(required_attributes).to include('name')
      end

      it 'cannot create a new taxon if not an admin' do
        api_post :create, taxonomy_id: taxonomy.id, taxon: { name: 'Location' }
        assert_unauthorized!
      end

      it 'cannot update a taxon' do
        api_put :update, taxonomy_id: taxonomy.id, id: taxon.id, taxon: { name: 'I hacked your store!' }
        assert_unauthorized!
      end

      it 'cannot delete a taxon' do
        api_delete :destroy, taxonomy_id: taxonomy.id, id: taxon.id
        assert_unauthorized!
      end
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create' do
        api_post :create, taxonomy_id: taxonomy.id, taxon: { name: 'Colors' }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)

        expect(taxonomy.reload.root.children.count).to eq 3
        taxon = Spree::Taxon.where(name: 'Colors').first

        expect(taxon.parent_id).to eq taxonomy.root.id
        expect(taxon.taxonomy_id).to eq taxonomy.id
      end

      it 'can update the position in the list' do
        taxonomy.root.children << taxon2
        api_put :update, taxonomy_id: taxonomy.id, id: taxon.id, taxon: { parent_id: taxon.parent_id, child_index: 2 }
        expect(response.status).to eq(200)
        expect(taxonomy.reload.root.children[0]).to eql rust_taxon
        expect(taxonomy.reload.root.children[1]).to eql taxon2
      end

      it 'cannot create a new taxon with invalid attributes' do
        api_post :create, taxonomy_id: taxonomy.id, taxon: { foo: :bar }
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Invalid resource. Please fix errors and try again.')
        expect(taxonomy.reload.root.children.count).to eq 2
      end

      it 'cannot create another root taxon' do
        api_post :create, taxonomy_id: taxonomy.id, taxon: { name: 'foo', parent_id: nil }
        expect(json_response[:errors][:root_conflict].first).to eq 'this taxonomy already has a root taxon'
      end

      it 'cannot create a new taxon with invalid taxonomy_id' do
        api_post :create, taxonomy_id: 1000, taxon: { name: 'Colors' }
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Invalid resource. Please fix errors and try again.')

        errors = json_response['errors']
        expect(errors['taxonomy_id']).not_to be_nil
        expect(errors['taxonomy_id'].first).to eq 'Invalid taxonomy id.'

        expect(taxonomy.reload.root.children.count).to eq 2
      end

      it 'can destroy' do
        api_delete :destroy, taxonomy_id: taxonomy.id, id: taxon.id
        expect(response.status).to eq(204)
      end
    end
  end
end
