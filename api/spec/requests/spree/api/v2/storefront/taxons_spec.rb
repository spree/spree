require 'spec_helper'

describe 'Taxons Spec', type: :request do
  let!(:taxonomy)  { create(:taxonomy) }
  let!(:taxons)    { create_list(:taxon, 2, taxonomy: taxonomy, parent_id: taxonomy.root.id) }

  shared_examples 'returns valid taxon resource JSON' do
    it 'returns a valid taxon resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data']).to have_type('taxon')
      expect(json_response['data']).to have_relationships(:parent, :taxonomy, :children, :products, :image)
    end
  end

  describe 'taxons#index' do
    it 'returns all taxons' do
      get '/api/v2/storefront/taxons'

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to eq(3)
      expect(json_response['data'][0]).to have_type('taxon')
      expect(json_response['data'][0]).to have_relationships(:parent, :children)
    end

    it 'returns taxons by roots' do
      get '/api/v2/storefront/taxons?roots=true'

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'][0]).to have_type('taxon')
      expect(json_response['data'][0]).to have_id(taxonomy.root.id.to_s)
      expect(json_response['data'][0]).to have_relationship(:parent).with_data(nil)
      expect(json_response['data'][0]).to have_relationships(:parent, :children)
    end

    it 'returns children taxons by parent' do
      get "/api/v2/storefront/taxons?parent_id=#{taxonomy.root.id}"

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to eq(2)
      expect(json_response['data'][0]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
      expect(json_response['data'][1]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
    end

    it 'returns taxons by taxonomy' do
      get "/api/v2/storefront/taxons?taxonomy_id=#{taxonomy.id}"

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to eq(3)
      expect(json_response['data'][0]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
      expect(json_response['data'][1]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
      expect(json_response['data'][2]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
    end

    it 'returns taxons by ids' do
      get "/api/v2/storefront/taxons?ids=#{taxons.map(&:id).join(',')}"

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to            eq(2)
      expect(json_response['data'].pluck(:id).sort).to eq(taxons.map(&:id).sort.map(&:to_s))
    end

    it 'returns taxons by name' do
      get "/api/v2/storefront/taxons?name=#{taxons.first.name}"

      expect(response.status).to eq(200)

      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'][0]).to have_id(taxons.first.id.to_s)
      expect(json_response['data'][0]).to have_attribute(:name).with_value(taxons.first.name)
    end
  end

  describe 'taxons#show' do
    context 'by id' do
      before do
        get "/api/v2/storefront/taxons/#{taxons.first.id}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by id' do
        expect(json_response['data']).to have_id(taxons.first.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(taxons.first.name)
      end
    end

    context 'by permalink' do
      before do
        get "/api/v2/storefront/taxons/#{Spree::Taxon.first.permalink}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by permalink' do
        expect(json_response['data']).to have_id(Spree::Taxon.first.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(Spree::Taxon.first.name)
      end
    end
  end
end
