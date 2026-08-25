# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Requirement Submissions API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let(:requirement) { create(:attestation_requirement, store: store) }

  path '/api/v3/seller/requirements/{requirement_id}/submissions' do
    parameter name: :requirement_id, in: :path, type: :string,
              description: 'Requirement ID, as returned by `GET /api/v3/seller/onboarding`'

    post 'Submit against a requirement' do
      tags 'Onboarding'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What the seller says about one requirement: an attestation they tick, a
        document they upload, a reference they paste.

        Create only. A submission records what was said and when, so a seller who
        needs to correct something submits again rather than editing, and the
        latest one counts.

        `file` is **not** a multipart upload — it is the `signed_id` returned by
        `POST /api/v3/seller/direct_uploads`, so the bytes are already in storage
        by the time this runs.

        An attestation is accepted on the spot; a requirement the operator
        reviews comes back `pending`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          note: { type: :string, description: 'Anything the seller wants to say alongside the submission' },
          reference: { type: :string, description: 'A reference number or external identifier, for requirements that ask for one' },
          file: { type: :string, description: 'A direct-upload `signed_id`, for requirements that ask for a document' }
        }
      }

      response '201', 'submission recorded' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:requirement_id) { requirement.prefixed_id }
        let(:body) { { note: 'Confirmed.' } }

        schema '$ref' => '#/components/schemas/RequirementSubmission'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to be_present
        end
      end

      response '404', "a requirement belonging to another marketplace" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:requirement_id) { create(:attestation_requirement, store: create(:store)).prefixed_id }
        let(:body) { { note: 'Confirmed.' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/requirement_submissions/{id}/download' do
    parameter name: :id, in: :path, type: :string, description: 'Submission ID'

    get 'Download a submitted document' do
      tags 'Onboarding'
      produces 'application/octet-stream'
      security [bearer_auth: []]
      description <<~DESC
        Streams the file attached to one of this seller's submissions.

        Served through the API rather than from a storage URL on purpose: these
        are identity and registration documents, so every read is authorized
        against the acting seller. Another seller's submission answers `404`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '404', "another seller's submission" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) do
          create(:seller_requirement_submission, seller: other_seller, requirement: requirement).prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
