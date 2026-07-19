# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Channel API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:wholesale) do
    create(:channel, store: store, code: 'wholesale', name: 'Wholesale',
                     preferred_storefront_access: 'login_required',
                     preferred_guest_checkout: false)
  end

  path '/api/v3/store/channel' do
    get 'Get the current channel' do
      tags 'Channel'
      produces 'application/json'
      security [api_key: []]
      description "Returns the channel this request resolved to (key binding → X-Spree-Channel header → store default), " \
                  'including the resolved storefront access posture. Reachable before authentication so gated ' \
                  'storefronts can render a sign-in wall.'

      sdk_example 'channel/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'X-Spree-Channel', in: :header, type: :string, required: false,
                description: 'Channel code or prefixed ID to resolve. When the API key is channel-bound, a value ' \
                             "naming a different channel is rejected with 422 channel_mismatch; a value matching the bound channel is accepted."

      response '200', 'channel found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'X-Spree-Channel') { wholesale.code }

        schema '$ref' => '#/components/schemas/Channel'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['code']).to eq('wholesale')
          expect(data['storefront_access']).to eq('login_required')
          expect(data['guest_checkout']).to be false
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:'X-Spree-Channel') { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
