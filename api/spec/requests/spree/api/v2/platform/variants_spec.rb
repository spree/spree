require 'spec_helper'

describe 'API V2 Platform Variants Spec' do
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  let(:product) { create(:product, stores: [store]) }
  let!(:variants) { create_list(:variant, 5, product: product) }
  
  describe 'variants#index' do
    context 'with no params' do
      before { get '/api/v2/platform/variants', headers: bearer_token }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all variants' do
        expect(json_response['data'].count).to eq store.variants.count
        expect(json_response['data'].first).to have_type('variant')
      end
    end

    context 'current store' do
      let(:store_2) { create(:store) }
      let(:product_2) { create(:product, stores: [store_2]) }
      let!(:variant_from_another_store) { create(:variant, product: product_2) }

      before { get '/api/v2/platform/variants', headers: bearer_token }

      it 'returns variants from this store only' do
        expect(json_response['data'].count).to eq store.variants.count
        variant_ids = json_response['data'].pluck(:id)

        expect(variant_ids).not_to include(variant_from_another_store.id)
        expect(variant_ids).to match_array(store.variants.ids.map(&:to_s))
      end
    end

    context 'filtering' do
      context 'by name' do
        let(:product_2) { create(:product, stores: [store], name: 'Vendo T-shirt') }
        let!(:variant) { create(:variant, product: product_2) }

        before { get "/api/v2/platform/variants?filter[product_name_cont]=vendo&filter[is_master_eq]=false", headers: bearer_token }

        it 'returns variant with a specified name' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first['id']).to eq variant.id.to_s
        end
      end

      xcontext 'by price' do
        let!(:variant) { create(:variant, price: 100) }

        before { get "/api/v2/platform/variants?filter[product_price_between]=100,200", headers: bearer_token }

        it 'returns variants with price greater than or equal to the given price' do
          expect(json_response['data'].count).to eq 1
          expect(json_response['data'].first['id']).to eq variant.id.to_s
        end
      end
    end

    context 'sorting' do
      context 'by updated_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/variants?sort=updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns variants sorted by updated_at' do
            expect(json_response['data'].count).to      eq store.variants.count
            expect(json_response['data'].pluck(:id)).to eq store.variants.order(:updated_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/variants?sort=-updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns variants sorted by updated_at with descending order' do
            expect(json_response['data'].count).to      eq store.variants.count
            expect(json_response['data'].pluck(:id)).to eq store.variants.order(updated_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'by created_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/variants?sort=created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns variants sorted by created_at' do
            expect(json_response['data'].count).to      eq store.variants.count
            expect(json_response['data'].pluck(:id)).to eq store.variants.order(:created_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/variants?sort=-created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns variants sorted by created_at with descending order' do
            expect(json_response['data'].count).to      eq store.variants.count
            expect(json_response['data'].pluck(:id)).to eq store.variants.order(created_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end
    end

    context 'paginate variants' do
      context 'with specified pagination params' do
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/platform/variants?page=1&per_page=2', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns the default number of variants' do
            expect(json_response['data'].count).to eq 2
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to       eq 2
            expect(json_response['meta']['total_count']).to eq store.variants.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/platform/variants?page=1&per_page=2')
            expect(json_response['links']['next']).to include('/api/v2/platform/variants?page=2&per_page=2')
            expect(json_response['links']['prev']).to include('/api/v2/platform/variants?page=1&per_page=2')
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/platform/variants', headers: bearer_token }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount variants' do
          expect(json_response['data'].count).to eq store.variants.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq store.variants.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/platform/variants')
          expect(json_response['links']['next']).to include('/api/v2/platform/variants?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/platform/variants?page=1')
        end
      end
    end
  end
end
