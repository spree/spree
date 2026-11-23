# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Diagnostics API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  path '/api/v3/admin/diagnostics' do
    get 'Get the diagnostics report' do
      tags 'Settings'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        An anonymised description of this installation to attach to a bug
        report: Spree and gem versions, runtime and infrastructure, settings
        changed from their defaults, and recent Spree errors by class and code
        location. It never contains names, emails, URLs, credentials or error
        messages. `markdown` is the same report ready to paste into a GitHub
        issue. Available to signed-in admins who can manage the store; a
        secret API key gets a 404.
      DESC

      admin_sdk_example 'diagnostics/get', signed_in: true

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :packages, in: :query, type: :string, required: false,
                description: "The caller's own `@spree/*` packages as comma-separated `name@version`, " \
                             'reported in a Dashboard section. Other entries are ignored.',
                example: '@spree/dashboard@6.0.4,@spree/admin-sdk@6.0.4'

      response '200', 'diagnostics report' do
        let(:Authorization) { "Bearer #{admin_jwt_token}" }
        let(:packages) { '@spree/dashboard@6.0.4' }

        # Keeps the documented example the same whichever machine generates it.
        before { allow(Etc).to receive(:uname).and_return(sysname: 'Linux', release: '6.8.0', machine: 'x86_64') }

        schema '$ref' => '#/components/schemas/Diagnostics'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['spree_version']).to eq(Spree.version)
          expect(data['markdown']).to start_with('<details>')
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
