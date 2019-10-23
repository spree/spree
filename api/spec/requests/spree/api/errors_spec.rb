require 'spec_helper'

describe 'API Errors Spec', type: :request do
  context 'unexisting API route' do
    it 'returns 404' do
      get '/api/prods'

      expect(response).to redirect_to('/api/v1/prods.json')
      follow_redirect!

      expect(response).to redirect_to('/api/404')
      follow_redirect!

      expect(response.status).to eq 404
    end
  end
end
