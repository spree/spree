require 'spec_helper'

describe 'Option Types Spec', type: :request do
  let!(:option_types) { create_list(:option_type, 2, filterable: false) }
  let!(:filterable_option_type) { create(:option_type, filterable: true) }

  let(:all_option_types) { option_types + [filterable_option_type] }

  before { Spree::Api::Config[:api_v2_per_page_limit] = 3 }

  shared_examples 'returns valid option type resource JSON' do
    it 'returns a valid option type resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data']).to have_type('option_type')
      expect(json_response['data']).to have_relationships(:option_values)
    end
  end

  describe 'option_types#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/option_types' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all option types' do
        expect(json_response['data'].size).to eq(3)
        expect(json_response['data'][0]).to have_type('option_type')
        expect(json_response['data'][0]).to have_relationships(:option_values)
        expect(json_response['data'][0]).not_to have_relationships(:products)
      end
    end

    context 'only filterable' do
      before { get '/api/v2/storefront/option_types?filter[filterable]=true' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns filterable option types' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'][0]).to have_type('option_type')
        expect(json_response['data'][0]).to have_id(filterable_option_type.id.to_s)
        expect(json_response['data'][0]).to have_relationships(:option_values)
      end
    end

    context 'paginate option_types' do
      context 'with specified pagination params' do
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/storefront/option_types?page=1&per_page=1' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns specified amount of option_types' do
            expect(json_response['data'].count).to eq 1
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to eq 1
            expect(json_response['meta']['total_count']).to eq Spree::OptionType.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/storefront/option_types?page=1&per_page=1')
            expect(json_response['links']['next']).to include('/api/v2/storefront/option_types?page=2&per_page=1')
            expect(json_response['links']['prev']).to include('/api/v2/storefront/option_types?page=1&per_page=1')
          end
        end

        context 'when per_page is above the default value' do
          before { get '/api/v2/storefront/option_types?page=1&per_page=10' }

          it 'returns the default number of option types' do
            expect(json_response['data'].count).to eq 3
          end
        end

        context 'when per_page is less than 0' do
          before { get '/api/v2/storefront/option_types?page=1&per_page=-1' }

          it 'returns the default number of option types' do
            expect(json_response['data'].count).to eq 3
          end
        end

        context 'when per_page is equal 0' do
          before { get '/api/v2/storefront/option_types?page=1&per_page=0' }

          it 'returns the default number of option types' do
            expect(json_response['data'].count).to eq 3
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/option_types' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount of option types' do
          expect(json_response['data'].count).to eq Spree::OptionType.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq Spree::OptionType.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/option_types')
          expect(json_response['links']['next']).to include('/api/v2/storefront/option_types?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/option_types?page=1')
        end
      end
    end
  end

  describe 'option_types#show' do
    context 'by id' do
      before do
        get "/api/v2/storefront/option_types/#{option_types.first.id}"
      end

      it_behaves_like 'returns valid option type resource JSON'

      it 'returns option type by id' do
        expect(json_response['data']).to have_id(option_types.first.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(option_types.first.name)
      end
    end
  end
end
