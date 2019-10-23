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
    context 'with no params' do
      before { get '/api/v2/storefront/taxons' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all taxons' do
        expect(json_response['data'].size).to eq(3)
        expect(json_response['data'][0]).to have_type('taxon')
        expect(json_response['data'][0]).to have_relationships(:parent, :children)
      end
    end

    context 'by roots' do
      before { get '/api/v2/storefront/taxons?filter[roots]=true' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns taxons by roots' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'][0]).to have_type('taxon')
        expect(json_response['data'][0]).to have_id(taxonomy.root.id.to_s)
        expect(json_response['data'][0]).to have_relationship(:parent).with_data(nil)
        expect(json_response['data'][0]).to have_relationships(:parent, :taxonomy, :children, :products, :image)
      end
    end

    context 'by parent' do
      before { get "/api/v2/storefront/taxons?filter[parent_id]=#{taxonomy.root.id}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns children taxons by parent' do
        expect(json_response['data'].size).to eq(2)
        expect(json_response['data'][0]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
        expect(json_response['data'][1]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
      end
    end

    context 'by taxonomy' do
      before { get "/api/v2/storefront/taxons?taxonomy_id=#{taxonomy.id}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns taxons by taxonomy' do
        expect(json_response['data'].size).to eq(3)
        expect(json_response['data'][0]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
        expect(json_response['data'][1]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
        expect(json_response['data'][2]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
      end
    end

    context 'by ids' do
      before { get "/api/v2/storefront/taxons?filter[ids]=#{taxons.map(&:id).join(',')}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns taxons by ids' do
        expect(json_response['data'].size).to            eq(2)
        expect(json_response['data'].pluck(:id).sort).to eq(taxons.map(&:id).sort.map(&:to_s))
      end
    end

    context 'by name' do
      before { get "/api/v2/storefront/taxons?filter[name]=#{taxons.last.name}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns taxonx by name' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].last['attributes']['name']).to eq(taxons.last.name)
      end
    end

    context 'paginate taxons' do
      context 'with specified pagination params' do
        before { get '/api/v2/storefront/taxons?page=1&per_page=1' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of taxons' do
          expect(json_response['data'].count).to eq 1
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq 1
          expect(json_response['meta']['total_count']).to eq Spree::Taxon.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/taxons?page=1&per_page=1')
          expect(json_response['links']['next']).to include('/api/v2/storefront/taxons?page=2&per_page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/taxons?page=1&per_page=1')
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/taxons' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of taxons' do
          expect(json_response['data'].count).to eq Spree::Taxon.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq Spree::Taxon.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/taxons')
          expect(json_response['links']['next']).to include('/api/v2/storefront/taxons?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/taxons?page=1')
        end
      end
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
