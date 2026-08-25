# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Invitation Acceptance API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:inviter) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:invitation) { create(:invitation, resource: seller, inviter: inviter, email: 'newcomer@acme.test') }

  path '/api/v3/seller/auth/invitations/{id}/lookup' do
    parameter name: :id, in: :path, type: :string, description: 'Invitation ID from the emailed link'

    get 'Look up an invitation' do
      tags 'Authentication'
      produces 'application/json'
      description <<~DESC
        Reads an invitation from the emailed link, before anyone signs in.

        The acceptance page needs the invited address to decide whether it is
        asking someone to set a new password or to confirm one they already have.

        Unauthenticated — the ID and token in the emailed link are the
        credential. A wrong token is indistinguishable from an unknown
        invitation: both answer `404`, so the endpoint cannot be used to
        enumerate. An invitation onto the store's own staff rather than a seller
        answers `404` here too.
      DESC

      parameter name: :token, in: :query, type: :string, required: true,
                description: 'The token from the emailed link'

      response '200', 'invitation found' do
        let(:id) { invitation.prefixed_id }
        let(:token) { invitation.token }

        schema '$ref' => '#/components/schemas/Invitation'

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('newcomer@acme.test')
        end
      end

      response '404', 'wrong token, or an invitation that can no longer be accepted' do
        let(:id) { invitation.prefixed_id }
        let(:token) { 'not-the-token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/auth/invitations/{id}/accept' do
    parameter name: :id, in: :path, type: :string, description: 'Invitation ID from the emailed link'

    post 'Accept an invitation' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Accepts the invitation and returns a signed-in seller session, so the new
        member lands in the panel rather than on a login form.

        The email is never taken from the request — it always comes from the
        invitation, which is what stops the link being redirected to another
        address.

        `password` is required when no account exists for the invited address, in
        which case it sets one. When an account already exists, the same field is
        how the person proves the account is theirs.
      DESC

      parameter name: :token, in: :query, type: :string, required: true,
                description: 'The token from the emailed link'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          password: { type: :string, example: 'password123' },
          password_confirmation: { type: :string, example: 'password123' },
          first_name: { type: :string, example: 'Robin' },
          last_name: { type: :string, example: 'Ellis' }
        }
      }

      response '200', 'invitation accepted, session issued' do
        let(:id) { invitation.prefixed_id }
        let(:token) { invitation.token }
        let(:body) do
          { password: 'password123', password_confirmation: 'password123', first_name: 'Robin', last_name: 'Ellis' }
        end

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq('newcomer@acme.test')
          expect(data['sellers'].first['id']).to eq(seller.prefixed_id)
        end
      end

      response '404', 'wrong token, or an invitation that can no longer be accepted' do
        let(:id) { invitation.prefixed_id }
        let(:token) { 'not-the-token' }
        let(:body) { { password: 'password123', password_confirmation: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
