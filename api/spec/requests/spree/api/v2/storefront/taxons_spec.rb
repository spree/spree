require 'spec_helper'

describe 'Taxons Spec', type: :request do
  let!(:default_store) { taxonomy.store }
  let!(:taxonomy) { create(:taxonomy) }
  let!(:taxons) { create_list(:taxon, 2, taxonomy: taxonomy, parent: taxonomy.root) }

  let(:store2)     { create(:store)}
  let!(:taxonomy2)  { create(:taxonomy, store: store2) }

  before { Spree::Api::Config[:api_v2_per_page_limit] = 2 }

  shared_examples 'returns valid taxon resource JSON' do
    it 'returns a valid taxon resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data']).to have_type('taxon')
      expect(json_response['data']).to have_relationships(:parent, :taxonomy, :children, :products, :image)
    end
  end

  describe 'taxons#index' do
    context 'with no params' do
      let(:default_store_taxons) { [taxonomy.root, taxons].flatten }

      before { get '/api/v2/storefront/taxons' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all taxons' do
        expect(json_response['data'].size).to eq(3)
        expect(json_response['data'][0]).to have_type('taxon')
        expect(json_response['data'][0]).to have_relationships(:parent, :taxonomy, :children, :image)
        expect(json_response['data'][0]).not_to have_relationships(:produts)
      end

      it 'should return only default store taxons' do
        expect(json_response['data'].map{ |t| t['id'] }).to match_array(default_store_taxons.pluck(:id).map(&:to_s))
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
        expect(json_response['data'][0]).to have_relationships(:parent, :taxonomy, :children, :image)
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

    context 'by parent permalink' do
      let!(:taxonomy_3) { create(:taxonomy, store: taxonomy.store) }
      let!(:taxon_3) { create(:taxon, taxonomy: taxonomy_3, parent: taxonomy_3.root) }

      before { get "/api/v2/storefront/taxons?filter[parent_permalink]=#{taxonomy.root.permalink}" }

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
        expect(json_response['data'].pluck(:id).sort).to eq(taxons.map(&:id).map(&:to_s).sort)
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
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/storefront/taxons?page=1&per_page=1' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns specified amount of taxons' do
            expect(json_response['data'].count).to eq 1
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to eq 1
            expect(json_response['meta']['total_count']).not_to eq Spree::Taxon.count
            expect(json_response['meta']['total_count']).to eq default_store.taxons.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/storefront/taxons?page=1&per_page=1')
            expect(json_response['links']['next']).to include('/api/v2/storefront/taxons?page=2&per_page=1')
            expect(json_response['links']['prev']).to include('/api/v2/storefront/taxons?page=1&per_page=1')
          end
        end

        context 'when per_page is above the default value' do
          before { get '/api/v2/storefront/taxons?page=1&per_page=10' }

          it 'returns the default number of taxons' do
            expect(json_response['data'].count).to eq 3
          end
        end

        context 'when per_page is less than 0' do
          before { get '/api/v2/storefront/taxons?page=1&per_page=-1' }

          it 'returns the default number of taxons' do
            expect(json_response['data'].count).to eq 3
          end
        end

        context 'when per_page is equal 0' do
          before { get '/api/v2/storefront/taxons?page=1&per_page=0' }

          it 'returns the default number of taxons' do
            expect(json_response['data'].count).to eq 3
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/taxons' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of taxons' do
          expect(json_response['data'].count).not_to eq Spree::Taxon.count
          expect(json_response['data'].count).to eq default_store.taxons.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).not_to eq Spree::Taxon.count
          expect(json_response['meta']['total_count']).to eq default_store.taxons.count
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
    let(:taxon) { taxons.first }

    context 'by id' do
      before do
        get "/api/v2/storefront/taxons/#{taxon.id}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by id' do
        expect(json_response['data']).to have_id(taxon.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(taxon.name)
      end
    end

    context 'by permalink' do
      before do
        get "/api/v2/storefront/taxons/#{default_store.taxons.first.permalink}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by permalink' do
        expect(json_response['data']).to have_id(default_store.taxons.first.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(default_store.taxons.first.name)
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

      before { get "/api/v2/storefront/taxons/#{taxon.id}?include=image#{taxon_image_transformation_params}" }

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
end
