# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Onboarding API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  path '/api/v3/seller/onboarding' do
    get 'Get onboarding checklist' do
      tags 'Onboarding'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What this marketplace asks of the seller before it will admit them.

        Singular: the checklist is always the acting seller's. Every answer is
        computed server-side by the same evaluator the operator's own view uses,
        so the panel and the operator can never show different progress.

        `progress` counts optional requirements too — it is how far along the
        checklist is, not how close to approval. Read `blocking` on each
        requirement for that.

        Each requirement's `id` is what a submission is posted against. A
        marketplace that asks for nothing returns an empty list, which is a
        complete answer rather than a missing one.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'checklist returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema '$ref' => '#/components/schemas/SellerOnboardingResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to be_present
          expect(data['requirements']).to be_an(Array)
        end
      end

      response '403', 'no seller named, or not a member of it' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/onboarding/submit_for_review' do
    post 'Submit for review' do
      tags 'Onboarding'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Says the seller is ready, moving them from `onboarding` to
        `ready_for_review`.

        Refused with `422` when something required is still outstanding — the
        message names the blocking requirements, and the seller's status is
        unchanged. Returns the same payload as the checklist so the panel can
        re-render from one response.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'submitted for review' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:seller) { create(:seller, :onboarding, store: store) }

        schema '$ref' => '#/components/schemas/SellerOnboardingResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('ready_for_review')
        end
      end

      # The description promises this refusal, so the reference has to carry it
      # — a client cannot handle a status the published contract omits.
      response '422', 'something required is still outstanding' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:seller) { create(:seller, :onboarding, store: store) }

        before { create(:accept_terms_requirement, store: store, required: true) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do
          expect(seller.reload.status).to eq('onboarding')
        end
      end
    end
  end

  path '/api/v3/seller/onboarding/payout_account' do
    post 'Get a payout account link' do
      tags 'Onboarding'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A fresh link to wherever the marketplace's payout provider collects
        what it needs before it will pay this seller. Ask for it when the
        seller acts: these links are short-lived and single-use. Answers
        `{ "url": null }` when the provider hosts no onboarding.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'payout account link' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:panel) { Spree::Sellers::PanelUrl.call(store: store) }
        let(:body) { { refresh_url: "#{panel}/onboarding", return_url: "#{panel}/onboarding?done=1" } }

        run_test! do |response|
          expect(JSON.parse(response.body)).to have_key('url')
        end
      end
    end
  end
end
