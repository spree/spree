require 'swagger_helper'

describe 'States API', swagger: true do
  include_context 'Platform API v2'

  path '/api/v2/platform/states' do
    get 'Returns a list of States' do
      tags 'States'
      security [ bearer_auth: [] ]
      operationId 'states-list'
      description 'Returns a list of States'
      before { create_list(:state, 2) }

      include_context 'jsonapi pagination'
      json_api_include_parameter('country')
      json_api_filter_parameter([{ name: 'filter[country_id_eq]', example: '4' }])

      it_behaves_like 'records returned'
      it_behaves_like 'authentication failed'
    end
  end

  path '/api/v2/platform/states/{id}' do
    let(:id) { create(:state).id }

    get 'Returns a State' do
      tags 'States'
      security [ bearer_auth: [] ]
      operationId 'show-state'
      description 'Returns a State'
      parameter name: :id, in: :path, type: :string

      it_behaves_like 'record found'
      it_behaves_like 'record not found'
      it_behaves_like 'authentication failed'
    end
  end
end
