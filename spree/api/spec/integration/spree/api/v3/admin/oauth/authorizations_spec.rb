# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin OAuth Consent API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:application) do
    store.oauth_applications.create!(
      name: 'Claude', redirect_uri: 'https://claude.ai/api/mcp/auth_callback', confidential: false
    )
  end
  let(:verifier) { SecureRandom.urlsafe_base64(64) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  before { Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp') }
  # The issuer is the deployment's configured host. The dummy app names
  # localhost for itself, which would put a developer's machine in the
  # published example, so here it is the origin the request arrives on — as
  # it is for an installation whose configured host is the one clients use.
  before { allow(::Doorkeeper.config).to receive(:issuer).and_return('http://www.example.com') }

  path '/api/v3/admin/oauth/authorize' do
    parameter name: :client_id, in: :query, type: :string, required: true,
              description: "The application's client id"
    parameter name: :redirect_uri, in: :query, type: :string, required: true,
              description: 'Must match what the application registered'
    parameter name: :response_type, in: :query, type: :string, required: true,
              description: 'Always `code`'
    parameter name: :scope, in: :query, type: :string, required: false,
              description: 'Space-delimited permission keys, the same vocabulary as API-key scopes'
    parameter name: :code_challenge, in: :query, type: :string, required: false,
              description: 'PKCE challenge. Required: these clients are public'
    parameter name: :code_challenge_method, in: :query, type: :string, required: false,
              description: 'Always `S256`'
    parameter name: :resource, in: :query, type: :string, required: false,
              description: 'RFC 8707: which protected resource the token is for'

    get 'Describe what a client is asking for' do
      tags 'OAuth'
      admin_sdk_example 'oauth-consent/show'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What the consent screen shows the merchant: who is asking, the
        permissions the requested scopes imply, and of those, the ones this
        person can actually hand over.

        A grant only ever narrows the approver's own authority, so anything
        they do not hold themselves is not offered.
      DESC

      response '200', 'the request described' do
        let(:client_id) { application.uid }
        let(:redirect_uri) { application.redirect_uri }
        let(:response_type) { 'code' }
        let(:scope) { 'read_products' }
        let(:code_challenge) { challenge }
        let(:code_challenge_method) { 'S256' }

        schema type: :object,
               properties: {
                 client_name: { type: :string },
                 scopes: { type: :array, items: { type: :string },
                           description: 'Every permission the requested scopes imply, expanded' },
                 grantable_scopes: { type: :array, items: { type: :string },
                                     description: 'Of those, the ones this person may hand over' },
                 resource: { type: :string, nullable: true },
                 redirect_uri: { type: :string }
               }

        run_test! do |response|
          expect(JSON.parse(response.body)['client_name']).to eq('Claude')
        end
      end
    end

    post 'Approve a request' do
      tags 'OAuth'
      admin_sdk_example 'oauth-consent/approve'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Records the grant and answers with where to send the browser. The
        scopes recorded are the ones this person may hand over, applied here
        rather than taken from the request — a grant is a standing ceiling,
        so one recorded too wide would widen on its own the day that person
        is promoted.
      DESC

      response '200', 'approved' do
        let(:client_id) { application.uid }
        let(:redirect_uri) { application.redirect_uri }
        let(:response_type) { 'code' }
        let(:scope) { 'read_products' }
        let(:code_challenge) { challenge }
        let(:code_challenge_method) { 'S256' }

        schema type: :object, properties: { redirect_uri: { type: :string } }

        run_test! do |response|
          expect(JSON.parse(response.body)['redirect_uri']).to include('code=')
        end
      end
    end

    delete 'Turn a request down' do
      tags 'OAuth'
      admin_sdk_example 'oauth-consent/deny'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Answers with where to send the browser, carrying the refusal.'

      response '200', 'denied' do
        let(:client_id) { application.uid }
        let(:redirect_uri) { application.redirect_uri }
        let(:response_type) { 'code' }
        let(:scope) { 'read_products' }
        let(:code_challenge) { challenge }
        let(:code_challenge_method) { 'S256' }

        schema type: :object, properties: { redirect_uri: { type: :string } }

        run_test! do |response|
          expect(JSON.parse(response.body)['redirect_uri']).to include('error=access_denied')
        end
      end
    end
  end
end
