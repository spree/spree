require 'spec_helper'

describe 'API Errors Spec', type: :request do
  context 'unexisting API route' do
    it 'returns 404' do
      get '/api/prods'

      expect(response).to have_http_status 404
    end
  end
end
