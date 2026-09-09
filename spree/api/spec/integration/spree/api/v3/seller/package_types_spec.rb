# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Package Types API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_package_types write_package_types])
  end

  let!(:package_type) do
    create(:package_type, store: store, seller: seller, name: 'Standard mailer', default: true,
                          length: 30, width: 20, height: 15, weight: 0.4)
  end
  let!(:marketplace_carton) { create(:carton_package_type, store: store, name: 'Marketplace carton') }

  path '/api/v3/seller/package_types' do
    get 'List package types' do
      tags 'Package Types'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What this seller packs their goods into: the boxes their parcels ship
        in, the cartons their products are packed into, the pallets a
        wholesale order leaves on.

        The list carries the marketplace's own packaging alongside the
        seller's, so a seller can pack into the operator's standard cartons
        rather than measuring them again. Those rows report `editable: false`
        and are refused by every write.

        The row marked `default` is the box this seller's parcels are quoted
        with — its size and weight are added to every rate.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :owner, in: :query, type: :string, required: false, enum: ['mine'],
                description: "Narrows the list to the seller's own packaging, leaving out the marketplace's shared rows"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'package types listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/PackageType' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(package_type.prefixed_id, marketplace_carton.prefixed_id)
        end
      end
    end

    post 'Create a package type' do
      tags 'Package Types'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Records a piece of the seller's own packaging. Marking it `default`
        makes it the box their parcels are quoted with, and demotes whichever
        of their rows held the flag before — the marketplace's default is a
        different owner's row and is left alone.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          kind: { type: :string, enum: Spree::PackageType::KINDS },
          length: { type: :number, nullable: true },
          width: { type: :number, nullable: true },
          height: { type: :number, nullable: true },
          dimensions_unit: { type: :string, nullable: true },
          weight: { type: :number, nullable: true, description: "The empty package's own weight, added to every quote" },
          max_weight: { type: :number, nullable: true },
          weight_unit: { type: :string, nullable: true },
          default: { type: :boolean },
          metadata: { type: :object, nullable: true }
        },
        required: %w[name kind]
      }

      response '201', 'package type created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          { name: 'Large mailer', kind: 'box', length: 40, width: 30, height: 20,
            dimensions_unit: 'cm', weight: 0.6, weight_unit: 'kg' }
        end

        schema '$ref' => '#/components/schemas/PackageType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['kind']).to eq('box')
          expect(data['editable']).to be(true)
        end
      end

      response '422', 'validation error' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: 'Crate', kind: 'crate' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/package_types/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Package type ID'

    get 'Get a package type' do
      tags 'Package Types'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Returns one package type by prefixed ID — the seller's own, or a
        marketplace row they may pack into.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'package type found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { package_type.prefixed_id }

        schema '$ref' => '#/components/schemas/PackageType'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(package_type.prefixed_id)
        end
      end

      response '404', 'package type not found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { 'pkgtype_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a package type' do
      tags 'Package Types'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Changes the seller's own packaging. A marketplace row is not theirs to
        edit and answers 404.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          kind: { type: :string, enum: Spree::PackageType::KINDS },
          length: { type: :number, nullable: true },
          width: { type: :number, nullable: true },
          height: { type: :number, nullable: true },
          dimensions_unit: { type: :string, nullable: true },
          weight: { type: :number, nullable: true },
          max_weight: { type: :number, nullable: true },
          weight_unit: { type: :string, nullable: true },
          default: { type: :boolean },
          metadata: { type: :object, nullable: true }
        }
      }

      response '200', 'package type updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
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
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Retires one of the seller's own package types. The default box is
        refused — name another default first, or every parcel silently falls
        back to the marketplace's box.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'package type deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:spare) { create(:package_type, store: store, seller: seller, name: 'Spare mailer') }
        let(:id) { spare.prefixed_id }

        run_test!
      end
    end
  end
end
