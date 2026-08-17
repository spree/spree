# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Commission Rates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:commission_rate) do
    create(:commission_rate, store: store, name: 'Standard', kind: 'percentage', value: 10)
  end

  path '/api/v3/admin/commission_rates' do
    get 'List commission rates' do
      tags 'Commission Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        What the marketplace charges its sellers.

        Rates are returned in resolution order: the list is walked top-down and
        the first rate whose targeting matches the sale wins, so the order you
        see is the precedence. Move a rate with `position` on update.

        A rate carrying no rules matches every sale — `global` says so — which
        is how a marketplace expresses a single default. Because resolution
        stops at the first match, a global rate makes everything below it
        unreachable, so it belongs at the bottom.
      DESC
      admin_scope :read, :commissions

      admin_sdk_example 'commission_rates/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[enabled_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by whether the rate is in use'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-position`).'

      response '200', 'commission rates found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('CommissionRate')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(commission_rate.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a commission rate' do
      tags 'Commission Rates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Sets what the marketplace charges, and which sales it applies to.

        `rules` is the rate's whole targeting, sent inline. Rules are grouped by
        `subject_type` and matched AND across the groups, OR within one — so
        `[Cameras, Audio, VendorX]` reads "(Cameras OR Audio) AND VendorX",
        which is how a seller-and-category pairing is expressed. Send no rules
        to charge every sale.

        `commission_tax_rate` is VAT on the commission itself — the
        marketplace's own service to the seller, a separate supply from the
        sale. Leave it null to let the store's tax engine answer for wherever
        the seller's business sits.
      DESC
      admin_scope :write, :commissions

      admin_sdk_example 'commission_rates/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name kind value],
        properties: {
          name: { type: :string, example: 'Audio sellers' },
          code: { type: :string, example: 'audio', nullable: true,
                  description: 'Your own identifier for this rate; unique per store.' },
          enabled: { type: :boolean, example: true },
          position: { type: :integer, example: 1,
                      description: 'Place in the list. Rates resolve top-down, so 1 is tried first. ' \
                                   'New rates are created at the top; send this to move one.' },
          kind: { type: :string, enum: %w[percentage fixed], example: 'percentage' },
          value: { type: :string, example: '12.5',
                   description: 'A percentage (10 = 10%) or a flat amount, per `kind`.' },
          currency: { type: :string, example: 'USD', nullable: true,
                      description: 'Required for a fixed rate, ignored for a percentage.' },
          include_tax: { type: :boolean, example: false,
                         description: 'Charge on the price including the customer\'s VAT. Left off, commission is ' \
                                      "charged on the seller's net revenue, which is the usual basis where the " \
                                      'fee is taxed as its own supply.' },
          include_shipping: { type: :boolean, example: false,
                              description: "Also charge commission on the seller's delivery revenue." },
          min_amount: { type: :string, example: '1.0', nullable: true },
          max_amount: { type: :string, example: '50.0', nullable: true },
          commission_tax_rate: { type: :string, example: '0.21', nullable: true,
                                 description: 'A fraction, not a percentage. Null asks the tax engine.' },
          rules: {
            type: :array,
            description: 'The full targeting; what you send replaces what the rate holds.',
            items: {
              type: :object,
              properties: {
                subject_type: { type: :string, enum: ['Spree::Product', 'Spree::Category', 'Spree::Vendor'] },
                subject_id: { type: :string, example: 'ven_a1b2c3' }
              }
            }
          }
        }
      }

      response '201', 'commission rate created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Audio sellers', kind: 'percentage', value: 12.5 } }

        schema '$ref' => '#/components/schemas/CommissionRate'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Audio sellers')
        end
      end

      response '422', 'validation failed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        # A flat fee means nothing without a currency to charge it in.
        let(:body) { { name: 'Flat fee', kind: 'fixed', value: 2 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/commission_rates/rule_subject_types' do
    get 'List what a commission rule may target' do
      tags 'Commission Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The subject types a rule may name, so a client can build its picker
        without hardcoding a list core owns.
      DESC
      admin_scope :read, :commissions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'subject types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, example: 'Spree::Vendor' },
                       name: { type: :string, example: 'Vendor' }
                     }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('type')).to include('Spree::Vendor')
        end
      end
    end
  end

  path '/api/v3/admin/commission_rates/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Commission rate ID'

    get 'Get a commission rate' do
      tags 'Commission Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :commissions

      admin_sdk_example 'commission_rates/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'commission rate found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { commission_rate.prefixed_id }

        schema '$ref' => '#/components/schemas/CommissionRate'

        run_test!
      end

      response '404', 'commission rate not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'crate_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a commission rate' do
      tags 'Commission Rates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Editing a rate changes what the next sale is charged, never what a past
        one was: commission lines keep their own snapshot of the rate that
        applied.
      DESC
      admin_scope :write, :commissions

      admin_sdk_example 'commission_rates/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Standard' },
          enabled: { type: :boolean, example: true },
          position: { type: :integer, example: 1 },
          value: { type: :string, example: '15.0' },
          rules: {
            type: :array,
            items: {
              type: :object,
              properties: {
                subject_type: { type: :string, example: 'Spree::Category' },
                subject_id: { type: :string, example: 'ctg_a1b2c3' }
              }
            }
          }
        }
      }

      response '200', 'commission rate updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { commission_rate.prefixed_id }
        let(:body) { { value: 15 } }

        schema '$ref' => '#/components/schemas/CommissionRate'

        run_test! do |response|
          expect(JSON.parse(response.body)['value']).to eq('15.0')
        end
      end
    end

    delete 'Delete a commission rate' do
      tags 'Commission Rates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :commissions

      admin_sdk_example 'commission_rates/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'commission rate deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { commission_rate.prefixed_id }

        run_test!
      end
    end
  end
end
