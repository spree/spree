# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Package Types API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:package_type) do
    create(:carton_package_type, store: store, name: 'Master carton',
                                 length: 40, width: 30, height: 25, max_weight: 20)
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/package_types' do
    get 'List package types' do
      tags 'Package Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the store's packaging vocabulary: the box it ships parcels in
        and the cartons, pallets and containers a wholesale order leaves on.

        `volume` is the cubic meters the package occupies, converted from
        whatever unit its dimensions were recorded in — the figure freight
        volume rules compare against. It is null until all three sides are
        measured.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'package-types/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[kind_eq]', in: :query, type: :string, required: false,
                description: 'Filter by kind (`box`, `envelope`, `carton`, `pallet`, `container`)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'package types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('PackageType')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['id'] }).to include(package_type.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a package type' do
      tags 'Package Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a kind of packaging to the store.

        `weight` is the empty package's own weight, added to content weight on
        every quote; `max_weight` is what it can hold. Setting `default` makes
        this the box every parcel quote is built on, and demotes whichever row
        held that before.

        A variant references a `carton`-kind row to say what it is packed
        into; other kinds are the merchant's own vocabulary.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'package-types/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Euro pallet' },
          kind: { type: :string, enum: Spree::PackageType::KINDS, example: 'pallet' },
          length: { type: :number, example: 120 },
          width: { type: :number, example: 80 },
          height: { type: :number, example: 15 },
          dimensions_unit: { type: :string, enum: Spree::Variant::DIMENSION_UNITS, example: 'cm' },
          weight: { type: :number, example: 25 },
          max_weight: { type: :number, example: 1500 },
          weight_unit: { type: :string, enum: Spree::Variant::WEIGHT_UNITS, example: 'kg' },
          default: { type: :boolean, example: false }
        },
        required: %w[name kind]
      }

      response '201', 'package type created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { name: 'Euro pallet', kind: 'pallet', length: 120, width: 80, height: 15, dimensions_unit: 'cm' }
        end

        schema '$ref' => '#/components/schemas/PackageType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['kind']).to eq('pallet')
          expect(data['volume'].to_d).to eq(BigDecimal('0.144'))
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Crate', kind: 'crate' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/package_types/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Package type ID'

    get 'Get a package type' do
      tags 'Package Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single package type by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'package-types/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'package type found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { package_type.prefixed_id }

        schema '$ref' => '#/components/schemas/PackageType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(package_type.prefixed_id)
        end
      end

      response '404', 'package type not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'pkgtype_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a package type' do
      tags 'Package Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a package type. Every product packed in it follows the new geometry.'
      admin_scope :write, :settings

      admin_sdk_example 'package-types/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          length: { type: :number },
          width: { type: :number },
          height: { type: :number },
          max_weight: { type: :number },
          default: { type: :boolean }
        }
      }

      response '200', 'package type updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { package_type.prefixed_id }
        let(:body) { { max_weight: 25 } }

        schema '$ref' => '#/components/schemas/PackageType'

        run_test! do |response|
          expect(JSON.parse(response.body)['max_weight'].to_d).to eq(25)
        end
      end
    end

    delete 'Delete a package type' do
      tags 'Package Types'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes a kind of packaging. Refused while any variant is packed into
        it — repack those products first.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'package-types/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'package type deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { package_type.prefixed_id }

        run_test!
      end
    end
  end
end
