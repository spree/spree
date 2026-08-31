# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Profile API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  path '/api/v3/seller/profile' do
    get 'Get profile' do
      tags 'Profile'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The seller's own record.

        Singular by nature: the seller in play is always the one named by
        `X-Spree-Seller-Id`, never an id in the path — so a seller cannot address
        another seller here even by guessing one.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'profile returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/Profile'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(seller.prefixed_id)
        end
      end

      response '403', 'no seller named, or not a member of it' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update profile' do
      tags 'Profile'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Edits presentation, contact details and addresses.

        Readable but **not** writable, by design: `status` — the lifecycle belongs
        to the marketplace operator's workflows — the settlement terms, and
        `slug`, since a seller renaming their own storefront address would break
        every link pointing at it.

        `accept_terms: true` stamps the moment the seller accepted the
        marketplace's terms, which is what the matching onboarding requirement
        reads. One-way — sending `false` does not unmake the stamp.

        `custom_fields` is narrowed server-side to the definitions this
        marketplace's onboarding actually asks this seller for; a field nothing
        asked for is ignored rather than written.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Acme Supplies' },
          contact_email: { type: :string, format: 'email', nullable: true, example: 'hello@acme.test' },
          billing_email: { type: :string, format: 'email', nullable: true, example: 'billing@acme.test' },
          about: { type: :string, nullable: true, description: 'Sanitized HTML — the seller\'s public description' },
          legal_name: { type: :string, nullable: true, description: 'The business a commission invoice is made out to' },
          registration_number: { type: :string, nullable: true },
          logo: { type: :string, nullable: true, description: 'ActiveStorage signed id; `null` removes the attachment' },
          square_logo: { type: :string, nullable: true },
          cover_photo: { type: :string, nullable: true },
          accept_terms: { type: :boolean, description: 'Stamps acceptance of the marketplace terms' },
          billing_address: { type: :object, additionalProperties: true },
          custom_fields: {
            type: :array,
            items: {
              type: :object,
              properties: {
                custom_field_definition_id: { type: :string, example: 'cfd_abc123' },
                value: { description: 'Any JSON value the definition accepts' }
              }
            }
          }
        }
      }

      response '200', 'profile updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: 'Acme Supplies', contact_email: 'hello@acme.test' } }

        schema '$ref' => '#/components/schemas/Profile'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Acme Supplies')
        end
      end

      response '422', 'validation failed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
