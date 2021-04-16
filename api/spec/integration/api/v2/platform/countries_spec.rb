require 'swagger_helper'

describe 'Countries API', swagger: true do
  include_context 'Platform API v2'

  path '/api/v2/platform/countries' do
    get 'Returns a list of Countries' do
      tags 'Countries'
      security [ bearer_auth: [] ]
      before { create_list(:country, 2) }

      it_behaves_like 'records returned'
      it_behaves_like 'authentication failed'
    end
  end

  path '/api/v2/platform/countries/{id}' do
    let(:id) { create(:country).id }

    get 'Returns a Country' do
      tags 'Countries'
      security [ bearer_auth: [] ]
      parameter name: :id, in: :path, type: :string

      it_behaves_like 'record found'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
