# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Invitations API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let(:pending_invitation) do
    create(:invitation, resource: seller, inviter: seller_user, email: 'colleague@acme.test')
  end

  path '/api/v3/seller/invitations' do
    get 'List pending invitations' do
      tags 'Team'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Offers nobody has accepted yet, newest first.

        Pending only — an accepted invitation is a team member, and shows up on
        `GET /api/v3/seller/team` instead.

        Sending an invitation lives on `team`, because that is hiring. Chasing or
        withdrawing one is bookkeeping on the offer itself, so it lives here.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'invitations listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { pending_invitation }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Invitation' } }
               },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |invitation| invitation['id'] }).to include(pending_invitation.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/seller/invitations/{id}/resend' do
    parameter name: :id, in: :path, type: :string, description: 'Invitation ID'

    patch 'Resend an invitation' do
      tags 'Team'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Sends the invitation email again, for a colleague who never got the first
        one. An invitation whose window has closed is refused rather than
        re-sent.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'invitation resent' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { pending_invitation.prefixed_id }

        schema '$ref' => '#/components/schemas/Invitation'

        run_test!
      end

      response '404', "another seller's invitation" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) do
          create(:invitation, resource: other_seller, inviter: seller_user, email: 'elsewhere@acme.test').prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/invitations/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Invitation ID'

    delete 'Revoke an invitation' do
      tags 'Team'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Withdraws an offer that has not been accepted.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'invitation revoked' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { pending_invitation.prefixed_id }

        run_test!
      end

      response '404', "another seller's invitation" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) do
          create(:invitation, resource: other_seller, inviter: seller_user, email: 'elsewhere@acme.test').prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
