# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Newsletter Subscribers API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/newsletter_subscribers' do
    post 'Subscribe to the newsletter' do
      tags 'Newsletter Subscribers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Subscribes an email address to the newsletter for the current store.

        Behavior:

        - If the email is already verified for this store, the existing subscription is returned unchanged.
        - If the request is unauthenticated (guest), the subscription is created in an unverified state
          and two events are published: `newsletter_subscriber.subscription_requested` (carrying the
          `verification_token` and the validated `redirect_url`, intended for headless storefronts that
          want to send the confirmation email themselves via a webhook handler) and the legacy
          `newsletter_subscriber.subscribed` lifecycle event (which the bundled `spree_emails` package
          listens to and uses to send a default confirmation email). The confirmation link should point
          at `redirect_url?token=<verification_token>` and call `POST /newsletter_subscribers/verify`
          when the user clicks it.
        - If the request is authenticated via JWT and the customer's email matches the subscribed email,
          the subscription is auto-verified and no events are fired — the JWT already proves email
          ownership, so no confirmation email is needed.

        The optional `redirect_url` is where the verification token should land on the storefront. The
        server does not return a validation error when the URL is outside the store's
        [Allowed Origins](/developer/core-concepts/allowed-origins); instead, the URL is silently
        omitted from the webhook payload (secure-by-default). When no allow-list is configured on the
        store, the URL is also omitted. Callers therefore receive the same 201 regardless, and the
        webhook handler should fall back to the store's storefront URL when `redirect_url` is missing
        from the payload.

        Newsletter consent is preserved across registration: if a guest subscribes and later registers
        with the same email, the existing subscriber record is reused.
      DESC

      sdk_example 'newsletter-subscribers/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Optional Bearer JWT — when present, links the subscription to that customer'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'subscriber@example.com' },
          redirect_url: {
            type: :string,
            format: 'uri',
            example: 'https://your-store.com/newsletter/confirm',
            description: 'Storefront URL the verification token should be appended to. Silently omitted from the webhook payload when the store has allowed origins configured and this URL does not match one of them, or when no allowed origins are configured at all.'
          }
        },
        required: %w[email]
      }

      response '201', 'subscription created (or existing returned)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:body) { { email: 'subscriber@example.com' } }

        schema '$ref' => '#/components/schemas/NewsletterSubscriber'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('subscriber@example.com')
          expect(data['verified']).to eq(false)
          expect(data['id']).to be_present
          expect(data['customer_id']).to be_nil
        end
      end

      response '201', 'subscription created with a validated redirect_url' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:body) do
          {
            email: 'subscriber@example.com',
            redirect_url: 'https://storefront.example.com/newsletter/confirm'
          }
        end

        before do
          store.allowed_origins.create!(origin: 'https://storefront.example.com')
        end

        schema '$ref' => '#/components/schemas/NewsletterSubscriber'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('subscriber@example.com')
          expect(data['verified']).to eq(false)
        end
      end

      response '201', 'subscription created but redirect_url is dropped (not in allowed origins)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:body) do
          {
            email: 'subscriber@example.com',
            redirect_url: 'https://evil.example.com/phish'
          }
        end

        before do
          store.allowed_origins.create!(origin: 'https://storefront.example.com')
        end

        schema '$ref' => '#/components/schemas/NewsletterSubscriber'

        run_test! do |response|
          data = JSON.parse(response.body)
          # Subscription itself succeeds; the redirect_url is silently dropped from
          # the webhook event payload to prevent open-redirect / token-exfiltration.
          expect(data['email']).to eq('subscriber@example.com')
          expect(data['verified']).to eq(false)
        end
      end

      response '201', 'auto-verified when JWT matches subscribed email' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { email: user.email } }

        schema '$ref' => '#/components/schemas/NewsletterSubscriber'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq(user.email)
          expect(data['verified']).to eq(true)
          expect(data['customer_id']).to eq(user.prefixed_id)
        end
      end

      response '422', 'invalid email format' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:body) { { email: 'not-an-email' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('validation_error')
        end
      end
    end
  end

  path '/api/v3/store/newsletter_subscribers/verify' do
    post 'Verify a newsletter subscription' do
      tags 'Newsletter Subscribers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Confirms a pending newsletter subscription using the verification token sent by email.

        After successful verification:
        - The subscriber record is marked verified.
        - If the subscription is associated with a customer, that customer's `accepts_email_marketing`
          flag is set to `true`.
      DESC

      sdk_example 'newsletter-subscribers/verify'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          token: {
            type: :string,
            example: 'abc123def456',
            description: 'Verification token from the confirmation email'
          }
        },
        required: %w[token]
      }

      response '200', 'subscription verified' do
        let(:'x-spree-api-key') { api_key.token }
        let!(:subscriber) { create(:newsletter_subscriber, :unverified, email: 'pending@example.com', store: store) }
        let(:body) { { token: subscriber.verification_token } }

        schema '$ref' => '#/components/schemas/NewsletterSubscriber'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('pending@example.com')
          expect(data['verified']).to eq(true)
          expect(data['verified_at']).to be_present
        end
      end

      response '422', 'invalid or expired token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { token: 'not-a-real-token' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'missing token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('parameter_missing')
        end
      end
    end
  end
end
