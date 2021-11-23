require 'spec_helper'

describe 'Platform API v2 Taxons API' do
  include_context 'Platform API v2'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:store_2) { create(:store) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'taxons#index' do
    let!(:taxon) { create(:taxon, name: 'T-Shirts', taxonomy: taxonomy) }
    let!(:taxon_2) { create(:taxon, name: 'Pants', taxonomy: taxonomy) }
    let!(:taxon_3) { create(:taxon, name: 'T-Shirts', taxonomy: create(:taxonomy, store: store_2)) }

    context 'filtering' do
      before { get '/api/v2/platform/taxons?filter[name_i_cont]=shirt', headers: bearer_token }

      it 'returns taxons with matching name' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].first).to have_id(taxon.id.to_s)
        expect(json_response['data'].first).to have_relationships(:taxonomy, :parent, :children, :image)
      end
    end

    context 'sorting' do
      before { get '/api/v2/platform/taxons?sort=name', headers: bearer_token }

      it 'returns taxons sorted by name' do
        expect(json_response['data'].count).to eq taxonomy.taxons.count
        expect(json_response['data'].first).to have_id(taxon_2.id.to_s)
      end
    end
  end

  describe 'taxons#show' do
    let!(:taxon) { create(:taxon, name: 'T-Shirts', taxonomy: taxonomy) }

    context 'with valid id' do
      before { get "/api/v2/platform/taxons/#{taxon.id}", headers: bearer_token }

      it 'returns taxon' do
        expect(json_response['data']).to have_id(taxon.id.to_s)
        expect(json_response['data']).to have_relationships(:taxonomy, :parent, :children, :image, :products)
      end
    end

    context 'with taxon image data' do
      shared_examples 'returns taxon image data' do
        it 'returns taxon image data' do
          expect(json_response['included'].count).to eq(1)
          expect(json_response['included'].first['type']).to eq('taxon_image')
        end
      end

      let!(:image) { create(:taxon_image, viewable: taxon) }
      let(:image_json_data) { json_response['included'].first['attributes'] }

      before { get "/api/v2/storefront/taxons/#{taxon.id}?include=image#{taxon_image_transformation_params}", headers: bearer_token }

      context 'when no image transformation params are passed' do
        let(:taxon_image_transformation_params) { '' }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns taxon image data'

        it 'returns taxon image' do
          expect(image_json_data['transformed_url']).to be_nil
        end
      end

      context 'when taxon image json returned' do
        let(:taxon_image_transformation_params) { '&taxon_image_transformation[size]=100x50&taxon_image_transformation[quality]=50' }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns taxon image data'

        it 'returns taxon image' do
          expect(image_json_data['transformed_url']).not_to be_nil
        end
      end
    end
  end

  shared_examples 'a resource containing metadata' do
    describe 'public metadata' do
      let(:metadata_params) { { public_metadata: public_metadata_params } }

      describe 'string entry' do
        let(:public_metadata_params) { { ability_to_recycle: '60%' } }

        it 'adds the metadata property' do
          expect(json_response['data']['attributes']['public_metadata']['ability_to_recycle']).to eq('60%')
        end
      end

      describe 'number entry' do
        let(:public_metadata_params) { { profitability: 3.4 } }

        it { expect(json_response['data']['attributes']['public_metadata']['profitability']).to eq('3.4') }
      end

      describe 'boolean entry' do
        let(:public_metadata_params) { { in_foreign_country: true } }

        it { expect(json_response['data']['attributes']['public_metadata']['in_foreign_country']).to eq('true') }
      end

      describe 'array entry' do
        let(:public_metadata_params) { { top_years: %w[2011 2016 2020] } }

        it { expect(json_response['data']['attributes']['public_metadata']['top_years']).to eq(%w[2011 2016 2020]) }
      end
    end

    describe 'private metadata' do
      let(:metadata_params) { { private_metadata: private_metadata_params } }

      describe 'string entry' do
        let(:private_metadata_params) { { ability_to_recycle: '60%' } }

        it { expect(json_response['data']['attributes']['private_metadata']['ability_to_recycle']).to eq('60%') }
      end

      describe 'number entry' do
        let(:private_metadata_params) { { profitability: 3.4 } }

        it { expect(json_response['data']['attributes']['private_metadata']['profitability']).to eq('3.4') }
      end

      describe 'boolean entry' do
        let(:private_metadata_params) { { in_foreign_country: false } }

        it { expect(json_response['data']['attributes']['private_metadata']['in_foreign_country']).to eq('false') }
      end

      describe 'array entry' do
        let(:private_metadata_params) { { top_years: %w[2011 2016 2020] } }

        it { expect(json_response['data']['attributes']['private_metadata']['top_years']).to eq(%w[2011 2016 2020]) }
      end
    end
  end

  describe 'taxons#update for metadata' do
    let!(:taxon) { create(:taxon, name: 'T-Shirts', taxonomy: taxonomy) }

    before do
      patch "/api/v2/platform/taxons/#{taxon.id}",
            headers: bearer_token,
            params: { taxon: metadata_params }
    end

    it_behaves_like 'a resource containing metadata'
  end

  describe 'taxons#create for metadata' do
    before do
      post '/api/v2/platform/taxons/',
           headers: bearer_token,
           params: {
             taxon: {
               name: 'Tires',
               taxonomy_id: taxonomy.id,
               parent_id: taxonomy.root.id
             }.merge(metadata_params)
           }
    end

    it_behaves_like 'a resource containing metadata'
  end

  describe 'taxons#reposition' do
    let!(:taxon_a) { create(:taxon, name: 'T-Shirts', taxonomy: taxonomy) }
    let!(:taxon_b) { create(:taxon, name: 'Shorts', taxonomy: taxonomy) }
    let!(:taxon_c) { create(:taxon, name: 'Pants', taxonomy: taxonomy) }

    context 'with no params' do
      let(:params) do
        {
          taxon: {
            new_parent_id: nil,
            new_position_idx: nil
          }
        }
      end

      before do
        patch "/api/v2/platform/taxons/#{taxon_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with none existing parent ID' do
      let(:params) do
        {
          taxon: {
            new_parent_id: 999129192192,
            new_position_idx: 0
          }
        }
      end

      before do
        patch "/api/v2/platform/taxons/#{taxon_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with correct params' do
      let(:params) do
        {
          taxon: {
            new_parent_id: taxon_c.id,
            new_position_idx: 0
          }
        }
      end

      before do
        patch "/api/v2/platform/taxons/#{taxon_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'taxon_a can be nested inside another taxon_c' do
        reload_taxons

        expect(taxon_a.permalink).to eq("#{taxonomy.root.permalink}/pants/t-shirts")
        expect(taxon_a.parent_id).to eq(taxon_c.id)
        expect(taxon_a.depth).to eq(2)
      end
    end

    context 'with correct params moving within the same taxon' do
      let(:params) do
        {
          taxon: {
            new_parent_id: taxon_b.id,
            new_position_idx: 0
          }
        }
      end

      before do
        patch "/api/v2/platform/taxons/#{taxon_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 're-indexes the taxon' do
        reload_taxons

        expect(taxon_a.parent_id).to eq(taxon_b.id)
        expect(taxon_a.lft).to eq(taxon_b.lft + 1)
      end
    end

    def reload_taxons
      taxon_a.reload
      taxon_b.reload
      taxon_c.reload
    end
  end
end
