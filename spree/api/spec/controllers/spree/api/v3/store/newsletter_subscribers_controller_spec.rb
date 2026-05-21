# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::NewsletterSubscribersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create' do
    context 'with a valid guest email' do
      it 'creates an unverified newsletter subscriber' do
        expect {
          post :create, params: { email: 'GuestSubscriber@example.com ' }
        }.to change(Spree::NewsletterSubscriber, :count).by(1)

        expect(response).to have_http_status(:accepted)
        subscriber = Spree::NewsletterSubscriber.last
        expect(subscriber.email).to eq('guestsubscriber@example.com')
        expect(subscriber).not_to be_verified
        expect(json_response['message']).to be_present
      end
    end

    context 'with an existing verified subscriber' do
      let!(:subscriber) { create(:newsletter_subscriber, :verified, email: 'existing@example.com', store: store) }

      it 'returns accepted without creating a duplicate' do
        expect {
          post :create, params: { email: subscriber.email }
        }.not_to change(Spree::NewsletterSubscriber, :count)

        expect(response).to have_http_status(:accepted)
        expect(json_response['message']).to be_present
      end
    end

    context 'with an authenticated customer using their own email' do
      before do
        user.update!(accepts_email_marketing: false)
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'creates a verified subscriber and updates the user marketing flag' do
        expect {
          post :create, params: { email: user.email }
        }.to change { Spree::NewsletterSubscriber.verified.count }.by(1)

        expect(response).to have_http_status(:accepted)
        subscriber = Spree::NewsletterSubscriber.last
        expect(subscriber.email).to eq(user.email)
        expect(subscriber).to be_verified
        expect(subscriber.user).to eq(user)
        expect(user.reload.accepts_email_marketing).to be(true)
      end
    end

    context 'with an invalid email' do
      it 'returns a validation error' do
        post :create, params: { email: 'not-an-email' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['email']).to be_present
      end
    end
  end
end
