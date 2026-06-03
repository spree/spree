# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::NewsletterSubscribersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #request_unsubscribe' do
    context 'when the email matches a subscriber on the current store' do
      let!(:subscriber) { create(:newsletter_subscriber, :verified, store: store) }

      it 'returns 202 accepted' do
        post :request_unsubscribe, params: { email: subscriber.email }

        expect(response).to have_http_status(:accepted)
      end

      it 'publishes newsletter_subscriber.unsubscribe_requested with the unsubscribe_token' do
        expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event)
          .with('newsletter_subscriber.unsubscribe_requested', hash_including(:unsubscribe_token, :id, :email, :store_id))

        post :request_unsubscribe, params: { email: subscriber.email }
      end

      context 'with redirect_url' do
        context 'when redirect_url is in the store allowed origins' do
          let!(:allowed_origin) { create(:allowed_origin, store: store, origin: 'https://myshop.com') }

          it 'includes redirect_url in the event payload' do
            expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event)
              .with('newsletter_subscriber.unsubscribe_requested', hash_including(redirect_url: 'https://myshop.com/unsubscribe'))

            post :request_unsubscribe, params: { email: subscriber.email, redirect_url: 'https://myshop.com/unsubscribe' }
          end

          it 'silently drops redirect_url when it does not match allowed origins' do
            expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event)
              .with('newsletter_subscriber.unsubscribe_requested', hash_not_including(:redirect_url))

            post :request_unsubscribe, params: { email: subscriber.email, redirect_url: 'https://evil.com/phish' }

            expect(response).to have_http_status(:accepted)
          end
        end

        context 'when the store has no allowed origins' do
          it 'silently drops redirect_url' do
            expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event)
              .with('newsletter_subscriber.unsubscribe_requested', hash_not_including(:redirect_url))

            post :request_unsubscribe, params: { email: subscriber.email, redirect_url: 'https://anything.com/unsubscribe' }
          end
        end
      end
    end

    context 'when the email is unknown' do
      it 'returns 202 accepted (anti-enumeration)' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event)

        post :request_unsubscribe, params: { email: 'nobody@example.com' }

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'when the email belongs to a subscriber on a different store' do
      let(:other_store) { create(:store) }
      let!(:subscriber) { create(:newsletter_subscriber, :verified, store: other_store) }

      it 'returns 202 accepted and does not publish an event' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event)

        post :request_unsubscribe, params: { email: subscriber.email }

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'when email is missing' do
      it 'returns 202 accepted (anti-enumeration)' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event)

        post :request_unsubscribe, params: {}

        expect(response).to have_http_status(:accepted)
      end
    end
  end
end
