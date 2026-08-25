# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Team API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  path '/api/v3/seller/team' do
    get 'List team members' do
      tags 'Team'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The people who run this seller.

        Rooted at the acting seller throughout, so a seller only ever sees their
        own team. Unpaginated — a seller's team is small by nature.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'team members listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/TeamMember' } }
               },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |member| member['id'] }).to include(seller_user.prefixed_id)
        end
      end
    end

    post 'Invite a team member' do
      tags 'Team'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Invites a colleague onto this seller's team. They join when they accept,
        on the same invitation rail — and the same email — the marketplace
        operator's own invitations use.

        Hiring is not a lifecycle transition: a trading seller's status is
        untouched by taking someone on.

        The role is not a parameter. Every member holds the seller's own seeded
        role, which already carries the whole seller vocabulary.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'colleague@acme.test' }
        },
        required: %w[email]
      }

      response '201', 'invitation sent' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { email: 'colleague@acme.test' } }

        schema '$ref' => '#/components/schemas/Invitation'

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('colleague@acme.test')
        end
      end

      response '422', 'validation failed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { email: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/team/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Team member (user) ID'

    delete 'Remove a team member' do
      tags 'Team'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Revokes a member's access, removing every role they hold on this seller.

        The team can never reach zero: emptying it would leave a seller nobody
        can sign in to, and only the marketplace operator could put someone back.
        The last remaining member is refused with `422`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'member removed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:colleague) do
          create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
        end
        let(:id) { colleague.prefixed_id }

        run_test!
      end

      response '422', 'cannot remove the last remaining member' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { seller_user.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'not a member of this seller' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { create(:admin_user, :without_admin_role).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
