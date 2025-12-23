require 'spec_helper'

RSpec.describe Spree::Admin::SearchController, type: :request do
  stub_authorization!

  describe 'GET /admin/search/option_values' do
    let!(:option_type) { create(:option_type, name: 'color', presentation: 'Color') }
    let!(:option_type2) { create(:option_type, name: 'size', presentation: 'Size') }
    let!(:option_value1) { create(:option_value, name: 'red', presentation: 'Red', option_type: option_type) }
    let!(:option_value2) { create(:option_value, name: 'blue', presentation: 'Blue', option_type: option_type) }
    let!(:option_value3) { create(:option_value, name: 'green', presentation: 'Green', option_type: option_type) }
    let!(:option_value4) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type2) }
    let!(:option_value5) { create(:option_value, name: 'medium', presentation: 'Medium', option_type: option_type2) }
    let!(:option_value6) { create(:option_value, name: 'large', presentation: 'Large', option_type: option_type2) }

    context 'when query is present' do
      it 'returns matching option values with option type presentation' do
        get '/admin/search/option_values', params: { q: 'red' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([
          {
            'id' => option_value1.id,
            'name' => 'Color: Red'
          }
        ])
      end

      it 'returns multiple matching option values' do
        get '/admin/search/option_values', params: { q: 'e' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(5)
        expect(json_response.map { |ov| ov['name'] }).to match_array([
          'Color: Red',
          'Color: Blue',
          'Color: Green',
          'Size: Medium',
          'Size: Large'
        ])
      end

      it 'returns empty array when no matches found' do
        get '/admin/search/option_values', params: { q: 'yellow' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'when query is empty' do
      it 'returns empty array' do
        get '/admin/search/option_values', params: { q: '' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end

      it 'returns empty array when query is only whitespace' do
        get '/admin/search/option_values', params: { q: '   ' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'when query parameter is missing' do
      it 'returns empty array' do
        get '/admin/search/option_values'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end

  describe 'GET /admin/search/tags' do
    let!(:tag1) { ActsAsTaggableOn::Tag.create!(name: 'summer') }
    let!(:tag2) { ActsAsTaggableOn::Tag.create!(name: 'winter') }
    let!(:tag3) { ActsAsTaggableOn::Tag.create!(name: 'autumn') }
    let!(:tag4) { ActsAsTaggableOn::Tag.create!(name: 'spring') }

    context 'when query is present' do
      it 'returns matching tags' do
        get '/admin/search/tags', params: { q: 'summer' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([
          {
            'id' => tag1.id,
            'name' => 'summer'
          }
        ])
      end

      it 'returns multiple matching tags' do
        get '/admin/search/tags', params: { q: 'er' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response.map { |tag| tag['name'] }).to match_array(['summer', 'winter'])
      end

      it 'returns tags case-insensitively' do
        get '/admin/search/tags', params: { q: 'SUMMER' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([
          {
            'id' => tag1.id,
            'name' => 'summer'
          }
        ])
      end

      it 'returns empty array when no matches found' do
        get '/admin/search/tags', params: { q: 'tropical' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'when query is empty' do
      it 'returns empty array' do
        get '/admin/search/tags', params: { q: '' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end

      it 'returns empty array when query is only whitespace' do
        get '/admin/search/tags', params: { q: '   ' }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'when query parameter is missing' do
      it 'returns empty array' do
        get '/admin/search/tags'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end
end
