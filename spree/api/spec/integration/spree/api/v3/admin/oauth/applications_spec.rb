# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin OAuth Applications API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:application) do
    store.oauth_applications.create!(
      name: 'Claude', redirect_uri: 'https://claude.ai/api/mcp/auth_callback', confidential: false
    )
  end

  path '/api/v3/admin/oauth/applications' do
    get 'List connected applications' do
      tags 'OAuth'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Which agents and apps hold access to this store. Each one reports the
        permissions it was granted, when it was last authorized and who
        approved it, read from its live tokens.
      DESC
      admin_scope :read, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'applications listed' do
        before { application }

        schema SwaggerSchemaHelpers.paginated('OauthApplication')

        run_test!
      end
    end

    post 'Register an application' do
      tags 'OAuth'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Registers a client that merchants can then connect. What the client
        may do is not set here — the merchant grants that at consent, so a
        registration carries no permissions of its own.

        Clients are public rather than confidential: a hosted connector
        cannot keep a secret, which is why PKCE is required.
      DESC
      admin_scope :write, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'application registered' do
        let(:body) { { name: 'Claude', redirect_uri: 'https://claude.ai/api/mcp/auth_callback' } }

        schema '$ref' => '#/components/schemas/OauthApplication'

        run_test! do |response|
          expect(JSON.parse(response.body)['client_id']).to be_present
        end
      end

      response '422', 'the registration is not valid' do
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/oauth/applications/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Application ID'

    get 'Get an application' do
      tags 'OAuth'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'application found' do
        let(:id) { application.prefixed_id }

        schema '$ref' => '#/components/schemas/OauthApplication'

        run_test!
      end
    end

    patch 'Update an application' do
      tags 'OAuth'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'application updated' do
        let(:id) { application.prefixed_id }
        let(:body) { { name: 'Claude Desktop' } }

        schema '$ref' => '#/components/schemas/OauthApplication'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Claude Desktop')
        end
      end
    end

    delete 'Remove an application' do
      tags 'OAuth'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Takes the registration away entirely. To stop a client working
        without removing it, revoke its tokens instead.
      DESC
      admin_scope :write, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'application removed' do
        let(:id) { application.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/oauth/applications/{application_id}/tokens' do
    parameter name: :application_id, in: :path, type: :string, required: true,
              description: 'Application ID'

    delete 'Revoke an application\'s access' do
      tags 'OAuth'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The off switch. Revokes every live token and grant this application
        holds, so a client that still has a token stops working on its next
        call. The registration itself stays, and a merchant can connect it
        again.
      DESC
      admin_scope :write, :oauth_applications

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'access revoked' do
        let(:application_id) { application.prefixed_id }

        run_test!
      end
    end
  end
end
