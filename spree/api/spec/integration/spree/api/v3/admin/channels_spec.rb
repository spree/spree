# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Channels API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:channel) { create(:channel, store: store, name: 'Wholesale', code: 'wholesale') }

  path '/api/v3/admin/channels' do
    get 'List channels' do
      tags 'Channels'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the channels configured for the current store.'
      admin_scope :read, :settings
      admin_sdk_example 'channels/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'channels found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Channel')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(channel.prefixed_id)
        end
      end
    end

    post 'Create a channel' do
      tags 'Channels'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new channel on the current store. `code` is normalized to a
        URL-safe slug (`Point of Sale` → `point-of-sale`); when omitted it's
        derived from `name`.
      DESC
      admin_scope :write, :settings
      admin_sdk_example 'channels/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Point of Sale' },
          code: { type: :string, example: 'pos', description: 'Slug — auto-derived from `name` when blank.' },
          active: { type: :boolean, default: true },
          default: { type: :boolean, default: false },
          preferred_order_routing_strategy: { type: :string, nullable: true,
                                              description: 'Routing strategy class name. `null` inherits the store setting.' },
          preferred_storefront_access: { type: :string, nullable: true, enum: %w[public prices_hidden login_required],
                                         description: 'Anonymous-visitor access posture. `null` inherits the store setting.' },
          preferred_guest_checkout: { type: :boolean, nullable: true,
                                      description: 'Whether guests can check out without an account. `null` inherits the store setting.' }
        }
      }

      response '201', 'channel created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Marketplace', code: 'marketplace' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['code']).to eq('marketplace')
        end
      end
    end
  end

  path '/api/v3/admin/channels/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a channel' do
      tags 'Channels'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :settings
      admin_sdk_example 'channels/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'channel found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { channel.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(channel.prefixed_id)
        end
      end
    end

    patch 'Update a channel' do
      tags 'Channels'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings
      admin_sdk_example 'channels/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          code: { type: :string },
          active: { type: :boolean },
          default: { type: :boolean },
          preferred_order_routing_strategy: { type: :string, nullable: true,
                                              description: 'Routing strategy class name. `null` inherits the store setting.' },
          preferred_storefront_access: { type: :string, nullable: true, enum: %w[public prices_hidden login_required],
                                         description: 'Anonymous-visitor access posture. `null` inherits the store setting.' },
          preferred_guest_checkout: { type: :boolean, nullable: true,
                                      description: 'Whether guests can check out without an account. `null` inherits the store setting.' }
        }
      }

      response '200', 'channel updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { channel.prefixed_id }
        let(:body) do
          { name: 'Wholesale (Updated)', preferred_storefront_access: 'login_required', preferred_guest_checkout: false }
        end

        run_test! do |response|
          channel.reload
          expect(channel.name).to eq('Wholesale (Updated)')
          expect(channel.preferred_storefront_access).to eq('login_required')
          expect(channel.preferred_guest_checkout).to be(false)
        end
      end
    end

    delete 'Delete a channel' do
      tags 'Channels'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings
      admin_sdk_example 'channels/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'channel deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { channel.prefixed_id }

        run_test! do |response|
          expect(Spree::Channel.find_by(id: channel.id)).to be_nil
        end
      end
    end
  end

  path '/api/v3/admin/channels/{id}/add_products' do
    parameter name: :id, in: :path, type: :string, required: true

    post 'Publish products on a channel' do
      tags 'Channels'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Publishes the listed products on this channel. Idempotent — re-publishing
        an already-published product updates its publication window. Products from
        sibling stores are silently dropped.
      DESC
      admin_scope :write, :products
      admin_sdk_example 'channels/add-products'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[product_ids],
        properties: {
          product_ids: { type: :array, items: { type: :string } },
          published_at: { type: :string, format: 'date-time', nullable: true,
                          description: 'When the publications go live. `null` means immediately.' },
          unpublished_at: { type: :string, format: 'date-time', nullable: true,
                            description: 'When the publications come down. `null` means never.' }
        }
      }

      response '200', 'products published' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { channel.prefixed_id }
        let(:product) { create(:product) }
        let(:body) { { product_ids: [product.prefixed_id] } }

        schema type: :object, properties: { product_count: { type: :integer } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('product_count' => 1)
          expect(channel.reload.products).to include(product)
        end
      end
    end
  end

  path '/api/v3/admin/channels/{id}/remove_products' do
    parameter name: :id, in: :path, type: :string, required: true

    post 'Unpublish products from a channel' do
      tags 'Channels'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Unpublishes the listed products from this channel.'
      admin_scope :write, :products
      admin_sdk_example 'channels/remove-products'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[product_ids],
        properties: {
          product_ids: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'products unpublished' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { channel.prefixed_id }
        let(:product) { create(:product) }
        let(:body) { { product_ids: [product.prefixed_id] } }

        before { channel.add_products([product.id]) }

        schema type: :object, properties: { product_count: { type: :integer } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('product_count' => 1)
          expect(channel.reload.products).not_to include(product)
        end
      end
    end
  end
end
