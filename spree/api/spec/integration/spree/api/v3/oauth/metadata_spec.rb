# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'OAuth Protected Resource Metadata', type: :request,
                                                    swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  before { Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp') }
  # The issuer is the deployment's configured host. The dummy app names
  # localhost for itself, which would put a developer's machine in the
  # published example, so here it is the origin the request arrives on — as
  # it is for an installation whose configured host is the one clients use.
  before { allow(::Doorkeeper.config).to receive(:issuer).and_return('http://www.example.com') }

  path '/api/v3/oauth/protected-resource/{resource_key}' do
    parameter name: :resource_key, in: :path, type: :string, required: true,
              description: 'Which protected surface, e.g. `mcp`'

    get 'Discover the authorization server' do
      tags 'OAuth'
      admin_sdk_example 'oauth-discovery/protected-resource'
      produces 'application/json'
      description <<~DESC
        RFC 9728. A client given a URL it cannot reach unauthenticated reads
        this to learn which authorization server guards it and which
        permissions that server accepts.

        Unauthenticated by design: a client has to read it before it holds
        anything.
      DESC

      response '200', 'metadata' do
        let(:resource_key) { 'mcp' }

        schema '$ref' => '#/components/schemas/OauthProtectedResource'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['authorization_servers']).to be_present
          expect(data['scopes_supported']).to be_present
        end
      end

      response '404', 'no such protected surface' do
        let(:resource_key) { 'nonsense' }

        run_test!
      end
    end
  end
end
