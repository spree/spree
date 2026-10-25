# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Seller Requirement Submissions API', type: :request,
                                                           swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:seller) { create(:seller, store: store) }
  let(:requirement) { create(:attestation_requirement, store: store) }
  let(:submission) { create(:seller_requirement_submission, seller: seller, requirement: requirement) }

  path '/api/v3/admin/sellers/{seller_id}/requirement_submissions' do
    parameter name: :seller_id, in: :path, type: :string, required: true, description: 'Seller prefixed ID'

    post 'Waive a requirement for one seller' do
      tags 'Sellers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Excuses one seller from something the marketplace asks of everyone,
        recording who decided and why. The seller's own branch is where a
        seller submits; this is the operator setting a requirement aside.
      DESC
      admin_scope :write, :sellers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[requirement_id],
        properties: {
          requirement_id: { type: :string, description: 'The requirement being waived' },
          review_note: { type: :string, description: 'Why it was waived',
                         example: 'Supplied under their parent company agreement.' }
        }
      }

      response '201', 'requirement waived' do
        let(:seller_id) { seller.prefixed_id }
        let(:body) do
          { requirement_id: requirement.prefixed_id,
            review_note: 'Supplied under their parent company agreement.' }
        end

        schema '$ref' => '#/components/schemas/SellerRequirementSubmission'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('waived')
        end
      end

      response '404', 'the requirement belongs to another store' do
        let(:seller_id) { seller.prefixed_id }
        let(:body) { { requirement_id: create(:attestation_requirement, store: create(:store)).prefixed_id } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/sellers/{seller_id}/requirement_submissions/{id}/accept' do
    parameter name: :seller_id, in: :path, type: :string, required: true, description: 'Seller prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Submission prefixed ID'

    patch 'Accept a submission' do
      tags 'Sellers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Passes what a seller sent in. A status moved by `PATCH` would skip
        the mail and the extension hooks, so each decision is its own action.
      DESC
      admin_scope :write, :sellers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          review_note: { type: :string, description: 'A note kept with the decision' }
        }
      }

      response '200', 'submission accepted' do
        let(:seller_id) { seller.prefixed_id }
        let(:id) { submission.prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/SellerRequirementSubmission'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('accepted')
        end
      end
    end
  end

  path '/api/v3/admin/sellers/{seller_id}/requirement_submissions/{id}/reject' do
    parameter name: :seller_id, in: :path, type: :string, required: true, description: 'Seller prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Submission prefixed ID'

    patch 'Reject a submission' do
      tags 'Sellers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Turns down what a seller sent in. The note is what they act on, so it
        travels with the decision.
      DESC
      admin_scope :write, :sellers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          review_note: { type: :string, example: 'Please send a clearer copy.' }
        }
      }

      response '200', 'submission rejected' do
        let(:seller_id) { seller.prefixed_id }
        let(:id) { submission.prefixed_id }
        let(:body) { { review_note: 'Please send a clearer copy.' } }

        schema '$ref' => '#/components/schemas/SellerRequirementSubmission'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('rejected')
        end
      end
    end
  end
end
