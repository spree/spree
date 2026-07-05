# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::PasswordResetsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create' do
    context 'with a valid email' do
      it 'returns 202 accepted' do
        post :create, params: { email: user.email }

        expect(response).to have_http_status(:accepted)
        expect(json_response['message']).to be_present
      end

      it 'publishes customer.password_reset_requested event' do
        expect_any_instance_of(Spree.user_class).to receive(:publish_event)
          .with('customer.password_reset_requested', hash_including(:reset_token))

        post :create, params: { email: user.email }
      end
    end

    context 'with an unknown email' do
      it 'returns 202 accepted (prevents email enumeration)' do
        post :create, params: { email: 'nonexistent@example.com' }

        expect(response).to have_http_status(:accepted)
        expect(json_response['message']).to be_present
      end
    end

    context 'with no email' do
      it 'returns 202 accepted (prevents email enumeration)' do
        post :create, params: {}

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with redirect_url' do
      context 'when store has allowed origins' do
        let!(:allowed_origin) { create(:allowed_origin, store: store, origin: 'https://myshop.com') }

        it 'returns 202 when redirect_url matches allowed origin' do
          post :create, params: { email: user.email, redirect_url: 'https://myshop.com/reset-password' }

          expect(response).to have_http_status(:accepted)
        end

        it 'includes redirect_url in event payload' do
          expect_any_instance_of(Spree.user_class).to receive(:publish_event)
            .with('customer.password_reset_requested', hash_including(redirect_url: 'https://myshop.com/reset-password'))

          post :create, params: { email: user.email, redirect_url: 'https://myshop.com/reset-password' }
        end

        it 'silently drops redirect_url when it does not match allowed origin' do
          expect_any_instance_of(Spree.user_class).to receive(:publish_event)
            .with('customer.password_reset_requested', hash_not_including(:redirect_url))

          post :create, params: { email: user.email, redirect_url: 'https://evil.com/phishing' }

          expect(response).to have_http_status(:accepted)
        end
      end

      context 'when store has no allowed origins' do
        it 'silently drops redirect_url to prevent open redirect' do
          expect_any_instance_of(Spree.user_class).to receive(:publish_event)
            .with('customer.password_reset_requested', hash_not_including(:redirect_url))

          post :create, params: { email: user.email, redirect_url: 'https://anything.com/reset' }

          expect(response).to have_http_status(:accepted)
        end
      end

      context 'without redirect_url' do
        it 'does not include redirect_url in event payload' do
          expect_any_instance_of(Spree.user_class).to receive(:publish_event)
            .with('customer.password_reset_requested', hash_not_including(:redirect_url))

          post :create, params: { email: user.email }
        end
      end
    end
  end

  describe 'PATCH #update' do
    let(:reset_token) { user.generate_token_for(:password_reset) }

    context 'with a valid token and matching passwords' do
      it 'resets the password and returns JWT' do
        patch :update, params: {
          id: reset_token,
          password: 'newsecurepassword',
          password_confirmation: 'newsecurepassword'
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']).to be_present
        expect(json_response['user']['email']).to eq(user.email)
      end

      it 'publishes customer.password_reset event' do
        expect_any_instance_of(Spree.user_class).to receive(:publish_event)
          .with('customer.password_reset')

        patch :update, params: {
          id: reset_token,
          password: 'newsecurepassword',
          password_confirmation: 'newsecurepassword'
        }
      end

      it 'invalidates the token after use' do
        patch :update, params: {
          id: reset_token,
          password: 'newsecurepassword',
          password_confirmation: 'newsecurepassword'
        }

        expect(response).to have_http_status(:ok)

        # Reusing the same token should fail because password salt changed
        patch :update, params: {
          id: reset_token,
          password: 'anotherpassword',
          password_confirmation: 'anotherpassword'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('password_reset_token_invalid')
      end
    end

    context 'with an invalid token' do
      it 'returns error' do
        patch :update, params: {
          id: 'invalid-token',
          password: 'newsecurepassword',
          password_confirmation: 'newsecurepassword'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('password_reset_token_invalid')
      end
    end

    context 'with mismatched passwords' do
      it 'returns validation error' do
        patch :update, params: {
          id: reset_token,
          password: 'newsecurepassword',
          password_confirmation: 'differentpassword'
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end
  end
end
