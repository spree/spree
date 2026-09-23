# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Account API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  path '/api/v3/seller/me' do
    get 'Current user' do
      tags 'Account'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The signed-in user, the sellers they may act for, and what they may do on
        the selected one.

        This is the one authenticated endpoint that answers without
        `X-Spree-Seller-Id` — it is what tells the panel which seller to name.
        Sending the header narrows `permission_keys` and `permissions` to that
        seller; without it both are empty, because capability is per seller and
        there is no answer spanning all of them.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: false,
                description: 'The seller to report capability for. Omit to list sellers without narrowing permissions.'

      response '200', 'current user returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/SellerMeResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['id']).to eq(seller_user.prefixed_id)
          expect(data['sellers'].first['id']).to eq(seller.prefixed_id)
          expect(data['permission_keys']).to include('write_products')
        end
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update your account' do
      tags 'Account'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Edits the signed-in person's own account — the name and photo their team
        sees, and the language their panel displays.

        This is the person, not the business: the seller they act for is
        `PATCH /profile`. Like `GET /me` it answers without
        `X-Spree-Seller-Id`, because the account is the same whichever seller
        they are acting for.

        `avatar` takes an ActiveStorage direct-upload signed id to set the
        photo, or `null` to remove it; omit it to leave the current one alone.
        `email` is identity-bound and cannot be changed here.
      DESC

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'Ada' },
          last_name: { type: :string, example: 'Lovelace' },
          selected_locale: { type: :string, example: 'de', description: 'Panel display language, as a code the panel ships.' },
          avatar: { type: :string, nullable: true, description: 'Direct-upload signed id, or `null` to remove the photo.' }
        }
      }

      response '200', 'account updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:body) { { first_name: 'Ada', last_name: 'Lovelace' } }

        schema '$ref' => '#/components/schemas/SellerMeResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['full_name']).to eq('Ada Lovelace')
        end
      end

      # The only way this endpoint refuses a well-formed request: the photo
      # must be a web image, since a seller's avatar is rendered in a browser.
      response '422', 'the photo is not a web image' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
            filename: 'avatar.svg',
            content_type: 'image/svg+xml'
          )
        end
        let(:body) { { avatar: blob.signed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'missing or invalid token' do
        let(:Authorization) { nil }
        let(:body) { { first_name: 'Ada' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
