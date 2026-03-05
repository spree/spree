require 'spec_helper'

RSpec.describe Spree::Api::V3::Idempotent, type: :controller do
  describe Spree::Api::V3::Store::CartController do
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

      it 'processes normally without Idempotency-Key header' do
        expect { post :create }.to change(Spree::Order, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.headers['Idempotent-Replayed']).to be_nil
      end

      it 'caches and replays the response for duplicate requests' do
        request.headers['Idempotency-Key'] = idempotency_key

        expect { post :create }.to change(Spree::Order, :count).by(1)
        expect(response).to have_http_status(:created)
        first_response = json_response

        expect { post :create }.not_to change(Spree::Order, :count)
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
        expect { post :create }.to change(Spree::Order, :count).by(1)

        request.headers['Idempotency-Key'] = 'key-2'
        expect { post :create }.to change(Spree::Order, :count).by(1)
      end

      it 'scopes cache by API key' do
        request.headers['Idempotency-Key'] = idempotency_key
        post :create
        first_response = json_response

        other_api_key = create(:api_key, :publishable, store: store)
        request.headers['X-Spree-Api-Key'] = other_api_key.token
        request.headers['Idempotency-Key'] = idempotency_key

        expect { post :create }.to change(Spree::Order, :count).by(1)
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
        cart = create(:order, store: store)
        request.headers['x-spree-order-token'] = cart.token
        request.headers['Idempotency-Key'] = idempotency_key

        get :show
        expect(response).to have_http_status(:ok)

        get :show
        expect(response).to have_http_status(:ok)
        expect(response.headers['Idempotent-Replayed']).to be_nil
      end
    end
  end
end
