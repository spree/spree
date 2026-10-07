require 'spec_helper'

RSpec.describe Spree::Api::V3::Idempotent, type: :controller do
  describe Spree::Api::V3::Store::CartsController do
    render_views

    include_context 'API v3 Store'

    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original_cache
    end

    before do
      request.headers['X-Spree-Api-Key'] = api_key.token
    end

    describe 'idempotency' do
      let(:idempotency_key) { SecureRandom.uuid }

      before { request.headers['Authorization'] = "Bearer #{jwt_token}" }

      it 'processes normally without Idempotency-Key header' do
        expect { post :create }.to change(Spree::Cart, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.headers['Idempotent-Replayed']).to be_nil
      end

      it 'caches and replays the response for duplicate requests' do
        request.headers['Idempotency-Key'] = idempotency_key

        expect { post :create }.to change(Spree::Cart, :count).by(1)
        expect(response).to have_http_status(:created)
        first_response = json_response

        expect { post :create }.not_to change(Spree::Cart, :count)
        expect(response).to have_http_status(:created)
        expect(response.headers['Idempotent-Replayed']).to eq('true')
        expect(json_response['id']).to eq(first_response['id'])
      end

      it 'rejects reuse of the same key with different request parameters' do
        request.headers['Idempotency-Key'] = idempotency_key

        post :create
        expect(response).to have_http_status(:created)

        post :create, params: { metadata: { source: 'mobile' } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('idempotency_key_reused')
      end

      it 'allows different idempotency keys for different requests' do
        request.headers['Idempotency-Key'] = 'key-1'
        expect { post :create }.to change(Spree::Cart, :count).by(1)

        request.headers['Idempotency-Key'] = 'key-2'
        expect { post :create }.to change(Spree::Cart, :count).by(1)
      end

      it 'scopes the cache to the caller, not to the shared publishable key' do
        request.headers['Idempotency-Key'] = idempotency_key
        post :create
        first_response = json_response

        other_customer = create(:user)
        request.headers['Authorization'] = "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(other_customer)}"

        expect { post :create }.to change(Spree::Cart, :count).by(1)
        expect(response.headers['Idempotent-Replayed']).to be_nil
        expect(json_response['id']).not_to eq(first_response['id'])
      end

      it 'rejects keys longer than 255 characters' do
        request.headers['Idempotency-Key'] = 'a' * 256

        post :create
        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']['code']).to eq('invalid_request')
      end

      it 'does not apply to GET requests' do
        cart = create(:cart, store: store)
        request.headers['x-spree-token'] = cart.token
        request.headers['Idempotency-Key'] = idempotency_key

        get :show, params: { id: cart.prefixed_id }
        expect(response).to have_http_status(:ok)

        get :show, params: { id: cart.prefixed_id }
        expect(response).to have_http_status(:ok)
        expect(response.headers['Idempotent-Replayed']).to be_nil
      end
    end

    describe 'callers that share a publishable key' do
      let(:idempotency_key) { 'checkout-1' }

      before { request.headers['Idempotency-Key'] = idempotency_key }

      it 'gives two guests their own cart rather than replaying the first one' do
        expect { post :create }.to change(Spree::Cart, :count).by(1)
        expect(response).to have_http_status(:created)
        first_response = json_response

        expect { post :create }.to change(Spree::Cart, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.headers['Idempotent-Replayed']).to be_nil
        expect(json_response['id']).not_to eq(first_response['id'])
        expect(json_response['token']).not_to eq(first_response['token'])
      end

      it 'replays for a guest that holds the cart token' do
        cart = create(:cart, store: store)
        request.headers['x-spree-token'] = cart.token

        patch :update, params: { id: cart.prefixed_id, email: 'guest@example.com' }
        expect(response).to have_http_status(:ok)

        patch :update, params: { id: cart.prefixed_id, email: 'guest@example.com' }
        expect(response).to have_http_status(:ok)
        expect(response.headers['Idempotent-Replayed']).to eq('true')
      end

      it 'does not replay once the cart token that authorized the write is gone' do
        cart = create(:cart, store: store)
        request.headers['Authorization'] = "Bearer #{jwt_token}"
        request.headers['x-spree-token'] = cart.token

        patch :update, params: { id: cart.prefixed_id, email: 'customer@example.com' }
        expect(response).to have_http_status(:ok)

        request.headers['x-spree-token'] = nil
        patch :update, params: { id: cart.prefixed_id, email: 'customer@example.com' }

        expect(response.headers['Idempotent-Replayed']).to be_nil
        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
