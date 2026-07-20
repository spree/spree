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

  path '/api/v3/store/newsletter_subscribers/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Newsletter subscriber prefix id (sub_*)'

    delete 'Unsubscribe from the newsletter' do
      tags 'Newsletter Subscribers'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Destroys the newsletter subscription, firing the `newsletter_subscriber.deleted`
        lifecycle event. Two authorization paths are accepted:

        - **Unsubscribe token** in the `?token=` query param — bearer delivered to the
          subscriber by email (the link in an unsubscribe message). The token is
          cryptographically signed and is cross-checked against the `:id` in the URL —
          tampering with either is rejected. To request such an email be sent, call the
          collection action `POST /newsletter_subscribers/request_unsubscribe` with the
          subscriber's email in the body.
        - **JWT bearer** for the logged-in customer who owns the subscription. No `token`
          query param is needed in this path.

        All failure modes return a generic `invalid_token` 422.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Optional Bearer JWT — alternative to the `token` query param'
      parameter name: :token, in: :query, type: :string, required: false,
                description: 'Unsubscribe token delivered to the subscriber by email (e.g. the link in an unsubscribe message).'

      response '204', 'unsubscribed via token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { subscriber.generate_token_for(:unsubscribe) }

        run_test! do
          expect(Spree::NewsletterSubscriber.find_by(id: subscriber.id)).to be_nil
        end
      end

      response '204', 'token path also flips the linked user\'s accepts_email_marketing flag' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, user: user, email: user.email, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { subscriber.generate_token_for(:unsubscribe) }

        before { user.update!(accepts_email_marketing: true) }

        run_test! do
          expect(Spree::NewsletterSubscriber.find_by(id: subscriber.id)).to be_nil
          expect(user.reload.accepts_email_marketing).to be(false)
        end
      end

      response '204', 'leaves accepts_email_marketing alone when subscriptions remain on other stores' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:other_store) { create(:store) }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, user: user, email: user.email, store: store) }
        let!(:other_subscriber) { create(:newsletter_subscriber, :verified, user: user, email: user.email, store: other_store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { subscriber.generate_token_for(:unsubscribe) }

        before { user.update!(accepts_email_marketing: true) }

        run_test! do
          expect(Spree::NewsletterSubscriber.find_by(id: subscriber.id)).to be_nil
          expect(Spree::NewsletterSubscriber.find_by(id: other_subscriber.id)).to be_present
          expect(user.reload.accepts_email_marketing).to be(true)
        end
      end

      response '204', 'unsubscribed via JWT (owner)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, user: user, email: user.email, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { nil }

        before { user.update!(accepts_email_marketing: true) }

        run_test! do
          expect(Spree::NewsletterSubscriber.find_by(id: subscriber.id)).to be_nil
          expect(user.reload.accepts_email_marketing).to be(false)
        end
      end

      response '422', 'neither token nor JWT supplied' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'token is malformed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { 'not-a-real-token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'id in URL does not match the token\'s subscriber' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber_a) { create(:newsletter_subscriber, :verified, store: store) }
        let!(:subscriber_b) { create(:newsletter_subscriber, :verified, store: store) }
        let(:id) { subscriber_a.prefixed_id }
        let(:token) { subscriber_b.generate_token_for(:unsubscribe) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'token for a subscriber on a different store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:other_store) { create(:store) }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: other_store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { subscriber.generate_token_for(:unsubscribe) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'token issued before the email was changed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, email: 'old@example.com', store: store) }
        let(:id) { subscriber.prefixed_id }
        let!(:token) { subscriber.generate_token_for(:unsubscribe) }

        before { subscriber.update!(email: 'new@example.com') }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'JWT-authenticated but not the owner' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:other_user) { create(:user) }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, user: other_user, email: other_user.email, store: store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '422', 'JWT-authenticated, subscriber on a different store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:other_store) { create(:store) }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, user: user, email: user.email, store: other_store) }
        let(:id) { subscriber.prefixed_id }
        let(:token) { nil }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end
    end
  end

  path '/api/v3/store/newsletter_subscribers/request_unsubscribe' do
    post 'Request an unsubscribe token' do
      tags 'Newsletter Subscribers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Publishes a `newsletter_subscriber.unsubscribe_requested` event carrying an unsubscribe token in the payload.
        Always returns 202 Accepted to prevent email enumeration.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'subscriber@example.com' },
          redirect_url: {
            type: :string,
            format: 'uri',
            description: 'Storefront URL the unsubscribe token should be appended to in the resulting email. Silently dropped from the event payload if outside the store\'s allowed origins.'
          }
        }
      }

      response '202', 'event published when the email matches a subscriber' do
        let(:'x-spree-api-key') { api_key.token }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: store) }
        let(:body) { { email: subscriber.email } }

        run_test!
      end

      response '202', 'no event published when the email is unknown' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: 'nobody@example.com' } }

        run_test!
      end

      response '202', 'no event published when the email belongs to a subscriber on another store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:other_store) { create(:store) }
        let!(:subscriber) { create(:newsletter_subscriber, :verified, store: other_store) }
        let(:body) { { email: subscriber.email } }

        run_test!
      end

      response '202', 'returns accepted even when email is missing' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { {} }

        run_test!
      end
    end
  end
end
