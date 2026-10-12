# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Updates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  path '/api/v3/admin/updates' do
    get 'Check for a newer Spree release' do
      tags 'Settings'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Whether a newer Spree release exists. The server asks spreecloud.io
        when it has no cached answer, for at most two seconds. A successful
        answer is kept for a day; a failed check is retried after an hour, so
        the call that retries it waits on it again. `checked_at` is null when
        the update check is turned off. Available to signed-in admins who can
        manage the store; a secret API key gets a 404.
      DESC

      admin_sdk_example 'updates/get', signed_in: true

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'update status' do
        let(:Authorization) { "Bearer #{admin_jwt_token}" }

        before do
          allow(Spree::UpdateCheck).to receive(:status).and_return(
            Spree::UpdateStatus.new(
              current_version: Spree.version,
              checked_at: Time.utc(2026, 10, 3, 4),
              releases: [{ version: '6.0.1', url: 'https://github.com/spree/spree/releases/tag/v6.0.1', published_at: Time.utc(2026, 10, 2, 10, 51, 38) }]
            )
          )
        end

        schema '$ref' => '#/components/schemas/UpdateStatus'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['update_available']).to be(true)
          expect(data['latest_version']).to eq('6.0.1')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
