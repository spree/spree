# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin API Keys API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:publishable_key) { create(:api_key, :publishable, store: store, name: 'Storefront key') }
  let!(:secret_key_record) do
    create(:api_key, :secret, store: store, name: 'Backend integration')
  end

  path '/api/v3/admin/api_keys' do
    get 'List API keys' do
      tags 'API Keys'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns publishable and secret API keys for the current store. ' \
                  'Secret keys are listed by `token_prefix` only — the plaintext token is delivered exactly once on create.'
      admin_scope :read, :api_keys

      admin_sdk_example 'api-keys/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'API keys found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('name')).to include('Storefront key', 'Backend integration')

          # Secret keys never leak `token` or `token_digest`. Publishable keys
          # serialize their plaintext token via `token_prefix` is fine.
          data['data'].each do |k|
            expect(k.keys).not_to include('token', 'token_digest')
          end
        end
      end
    end

    post 'Create an API key' do
      tags 'API Keys'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a publishable or secret API key. The plaintext token is included in the response **once** for secret keys; ' \
                  'publishable keys expose their token on every read since they are intended for client-side use.'
      admin_scope :write, :api_keys

      admin_sdk_example 'api-keys/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name key_type],
        properties: {
          name: { type: :string, example: 'Backend integration' },
          key_type: { type: :string, enum: %w[publishable secret] },
          scopes: { type: :array, items: { type: :string }, example: %w[read_orders write_orders] }
        }
      }

      response '201', 'secret key created — plaintext token returned once' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'CI key', key_type: 'secret', scopes: ['read_orders'] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('CI key')
          expect(data['key_type']).to eq('secret')
          expect(data['plaintext_token']).to be_present
          expect(data['plaintext_token']).to start_with('sk_')
          expect(data['token_prefix']).to eq(data['plaintext_token'][0, 12])
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '', key_type: 'secret' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/api_keys/{id}' do
    let(:id) { publishable_key.prefixed_id }

    get 'Show an API key' do
      tags 'API Keys'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :api_keys

      admin_sdk_example 'api-keys/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'API key found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(publishable_key.prefixed_id)
        end
      end
    end

    patch 'Update an API key' do
      tags 'API Keys'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Renames a key. `key_type` and `scopes` are fixed at creation — ' \
                  'to change a key\'s authority, create a new key and revoke the old one.'
      admin_scope :write, :api_keys

      admin_sdk_example 'api-keys/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Backend integration (renamed)' }
        }
      }

      response '200', 'API key renamed' do
        let(:id) { secret_key_record.prefixed_id }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Backend integration (renamed)' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Backend integration (renamed)')
        end
      end
    end

    delete 'Delete an API key' do
      tags 'API Keys'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :api_keys

      admin_sdk_example 'api-keys/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'API key deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/api_keys/current' do
    get 'Describe the current API key' do
      tags 'API Keys'
      produces 'application/json'
      security [api_key: []]
      description 'Returns the secret key that authenticated this request, including its ' \
                  'live scopes. Useful to confirm a key\'s real, current authority. ' \
                  'Only secret-key principals have a single key to describe.'
      admin_scope_note 'none — any key can describe itself'

      admin_sdk_example 'api-keys/current'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'current API key' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token_prefix']).to eq(secret_api_key.token_prefix)
          expect(data['scopes']).to eq(secret_api_key.scopes)
        end
      end
    end
  end

  path '/api/v3/admin/api_keys/{id}/revoke' do
    let(:id) { secret_key_record.prefixed_id }

    patch 'Revoke an API key' do
      tags 'API Keys'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Marks the key revoked. Future requests using its token will fail; the row is preserved for audit.'
      admin_scope :write, :api_keys

      admin_sdk_example 'api-keys/revoke'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'API key revoked' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['revoked_at']).to be_present
        end
      end
    end
  end
end
