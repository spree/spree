# frozen_string_literal: true

require 'swagger_helper'

# Both vendor addresses accept the same keys, so they document the same shape —
# a bare `type: :object` on one of them would leave SDK consumers without any
# property types for it.
VENDOR_ADDRESS_SCHEMA = {
  type: :object,
  description: "The vendor's own address, written inline. There is no " \
               '`billing_address_id` — an address belongs to whoever it was ' \
               'created for, so it is never referenced by id here.',
  properties: {
    first_name: { type: :string, example: 'Ada' },
    last_name: { type: :string, example: 'Lovelace' },
    company: { type: :string, example: 'Sparks Audio Ltd' },
    address1: { type: :string, example: '1 Vendor Way' },
    address2: { type: :string, example: 'Unit 4' },
    city: { type: :string, example: 'London' },
    postal_code: { type: :string, example: 'EC1A 1BB' },
    phone: { type: :string, example: '+44 20 7946 0000' },
    country_code: { type: :string, example: 'GB' },
    state_code: { type: :string, example: 'NY' },
    state_name: { type: :string, example: 'New York' },
    label: { type: :string, example: 'Head office' }
  }
}.freeze

RSpec.describe 'Admin Vendors API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:vendor) do
    create(:vendor, store: store, name: 'Sparks Audio', contact_email: 'hello@sparks.example')
  end

  path '/api/v3/admin/vendors' do
    get 'List vendors' do
      tags 'Vendors'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the sellers on this marketplace. `status` says where each one
        is in its life on the marketplace, and `sellable` answers the question
        the status alone cannot: an approved vendor who is away cannot be
        bought from either.
      DESC
      admin_scope :read, :vendors

      admin_sdk_example 'vendors/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                description: 'Filter by status'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'vendors found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Vendor')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(vendor.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a vendor' do
      tags 'Vendors'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Opens a seller record. The vendor starts as `pending` and has no team
        yet — invite someone to run it with the `invite` action below.

        `status` is deliberately not writable here or on update: every move
        through the lifecycle is its own action, because each one does more
        than set a column.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Northwind Books' },
          slug: { type: :string, example: 'northwind-books',
                  description: 'Derived from the name when omitted.' },
          contact_email: { type: :string, example: 'hi@northwind.example', nullable: true },
          billing_email: { type: :string, example: 'billing@northwind.example', nullable: true },
          about: { type: :string, example: '<p>Independent bookshop.</p>', nullable: true },
          tax_remittance: { type: :string, enum: %w[vendor platform], example: 'vendor' },
          payouts_schedule_interval: {
            type: :string, enum: %w[daily weekly biweekly monthly manual], nullable: true
          },
          minimum_payout_amount: { type: :string, example: '25.0', nullable: true }
        }
      }

      response '201', 'vendor created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Northwind Books', contact_email: 'hi@northwind.example' } }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Northwind Books')
          expect(data['status']).to eq('pending')
          expect(data['slug']).to eq('northwind-books')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/vendors/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Vendor prefixed ID'

    get 'Get a vendor' do
      tags 'Vendors'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single vendor, including its settlement and tax configuration.'
      admin_scope :read, :vendors

      admin_sdk_example 'vendors/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'vendor found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(vendor.prefixed_id)
          expect(data['contact_email']).to eq('hello@sparks.example')
        end
      end

      response '404', 'vendor not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'ven_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a vendor' do
      tags 'Vendors'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates the vendor's profile and the settlement configuration the
        operator owns. A `status` sent here is ignored — use the lifecycle
        actions.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Sparks Audio Ltd' },
          billing_email: { type: :string, example: 'billing@sparks.example', nullable: true },
          payouts_schedule_interval: {
            type: :string, enum: %w[daily weekly biweekly monthly manual], nullable: true
          },
          minimum_payout_amount: { type: :string, example: '25.0', nullable: true },
          holiday_mode_until: { type: :string, format: 'date-time', nullable: true },
          logo: {
            type: :string, nullable: true,
            description: 'ActiveStorage signed id of a direct-uploaded file. Send `null` ' \
                         'to remove the attachment, or omit the key to leave it alone. ' \
                         'Same for `square_logo` and `cover_photo`.'
          },
          square_logo: { type: :string, nullable: true },
          cover_photo: { type: :string, nullable: true },
          billing_address: VENDOR_ADDRESS_SCHEMA,
          returns_address: VENDOR_ADDRESS_SCHEMA
        }
      }

      response '200', 'vendor updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) { { billing_email: 'billing@sparks.example', payouts_schedule_interval: 'weekly' } }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['billing_email']).to eq('billing@sparks.example')
          expect(data['payouts_schedule_interval']).to eq('weekly')
        end
      end

      response '200', 'vendor address written inline' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) do
          {
            billing_address: {
              first_name: 'Ada', last_name: 'Lovelace', address1: '1 Vendor Way',
              city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB', phone: '555'
            }
          }
        end

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['billing_address']['address1']).to eq('1 Vendor Way')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a vendor' do
      tags 'Vendors'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Soft-deletes the vendor. Their products are kept and left without a
        seller rather than deleted — what happens to a departed seller's
        catalog is the operator's decision.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'vendor deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/vendors/{id}/invite' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Vendor prefixed ID'

    post 'Invite someone to run a vendor' do
      tags 'Vendors'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Sends an invitation to the vendor's own team and moves the vendor to
        `invited`. The person becomes a member when they accept, and can then
        sign in to the vendor panel.

        `role_id` must name a role this vendor owns; omit it for the vendor's
        own admin role. Re-inviting is allowed — an invitation expires, or the
        first one goes to the wrong address.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/invite'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[email],
        properties: {
          email: { type: :string, example: 'seller@example.com' },
          role_id: { type: :string, example: 'role_UkLWZg9DAJ', nullable: true }
        }
      }

      response '201', 'invitation sent' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) { { email: 'seller@example.com' } }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('invited')
        end
      end
    end
  end

  path '/api/v3/admin/vendors/{id}/approve' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Vendor prefixed ID'

    patch 'Approve a vendor' do
      tags 'Vendors'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Lets the vendor sell. This is also the way back for one that was
        suspended or turned down, and it clears any holiday along with the
        suspension.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/approve'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'vendor approved' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }

        before { vendor.update!(status: 'ready_for_review') }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('approved')
          expect(data['sellable']).to be(true)
        end
      end

      response '422', 'vendor cannot be approved from its current status' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }

        before { vendor.update!(status: 'approved') }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/vendors/{id}/suspend' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Vendor prefixed ID'

    patch 'Suspend a vendor' do
      tags 'Vendors'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Stops a trading vendor from selling. Their catalog and history stay,
        and approving reinstates them. Use this rather than `reject` for a
        vendor already on the marketplace — it says something different, and
        it can be undone.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/suspend'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: 'Counterfeit goods' }
        }
      }

      response '200', 'vendor suspended' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) { { reason: 'Counterfeit goods' } }

        before { vendor.update!(status: 'approved') }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('suspended')
          expect(data['sellable']).to be(false)
        end
      end
    end
  end

  path '/api/v3/admin/vendors/{id}/reject' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Vendor prefixed ID'

    patch 'Reject a vendor' do
      tags 'Vendors'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Turns down an applicant who never traded. A vendor already selling is
        suspended instead; rejecting one is refused.
      DESC
      admin_scope :write, :vendors

      admin_sdk_example 'vendors/reject'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: 'Incomplete paperwork' }
        }
      }

      response '200', 'vendor rejected' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { vendor.prefixed_id }
        let(:body) { { reason: 'Incomplete paperwork' } }

        before { vendor.update!(status: 'ready_for_review') }

        schema '$ref' => '#/components/schemas/Vendor'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('rejected')
        end
      end
    end
  end
end
