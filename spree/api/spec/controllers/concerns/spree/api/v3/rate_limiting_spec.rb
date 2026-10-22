require 'spec_helper'

RSpec.describe 'Rate Limiting', type: :controller do
  describe 'secret API keys' do
    describe Spree::Api::V3::Admin::CountriesController do
      controller(Spree::Api::V3::Admin::CountriesController) {}

      render_views

      include_context 'API v3 Admin'

      before do
        request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token
      end

      it 'counts against one API-wide bucket keyed by the digested secret key' do
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        digest = Spree::ApiKey.compute_token_digest(secret_api_key.plaintext_token)
        expect(Rails.cache).to have_received(:increment)
          .with("rate-limit:api_v3:#{digest}", 1, expires_in: 60.seconds)
      end

      it 'never uses the plaintext secret token as a cache key' do
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        expect(Rails.cache).not_to have_received(:increment)
          .with(a_string_including(secret_api_key.plaintext_token), anything, anything)
      end

      it 'refuses the request with a 429 once the limit is exceeded' do
        allow(Rails.cache).to receive(:increment)
          .and_return(Spree::Api::Config[:rate_limit_per_secret_key] + 1)

        get :index

        expect(response).to have_http_status(:too_many_requests)
        expect(json_response[:error][:code]).to eq('rate_limit_exceeded')
        expect(response.headers['Retry-After']).to eq(Spree::Api::Config[:rate_limit_window].to_s)
        expect(response.headers['X-RateLimit-Limit']).to eq(Spree::Api::Config[:rate_limit_per_secret_key].to_s)
        expect(response.headers['X-RateLimit-Remaining']).to eq('0')
      end

      it 'does not refuse requests at or under the limit' do
        allow(Rails.cache).to receive(:increment)
          .and_return(Spree::Api::Config[:rate_limit_per_secret_key])

        get :index

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'publishable API keys' do
    describe Spree::Api::V3::Store::CountriesController do
      controller(Spree::Api::V3::Store::CountriesController) {}

      render_views

      include_context 'API v3 Store'

      before do
        request.headers['X-Spree-Api-Key'] = api_key.token
      end

      it 'counts against a per-visitor bucket keyed by the key and client IP' do
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        expect(Rails.cache).to have_received(:increment)
          .with("rate-limit:api_v3:#{api_key.token}:0.0.0.0", 1, expires_in: 60.seconds)
      end

      it 'refuses the request with a 429 once the limit is exceeded' do
        allow(Rails.cache).to receive(:increment)
          .and_return(Spree::Api::Config[:rate_limit_per_key] + 1)

        get :index

        expect(response).to have_http_status(:too_many_requests)
        expect(json_response[:error][:code]).to eq('rate_limit_exceeded')
        expect(response.headers['X-RateLimit-Limit']).to eq(Spree::Api::Config[:rate_limit_per_key].to_s)
      end
    end
  end

  describe 'keyless requests (admin JWT traffic)' do
    describe Spree::Api::V3::Admin::CountriesController do
      controller(Spree::Api::V3::Admin::CountriesController) {}

      render_views

      include_context 'API v3 Admin'

      it 'counts against a per-IP bucket when no API key is present' do
        request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        expect(Rails.cache).to have_received(:increment)
          .with('rate-limit:api_v3:0.0.0.0', 1, expires_in: 60.seconds)
      end

      # Hosted connectors reach the API from a handful of shared addresses,
      # so one merchant's agent would exhaust every other merchant's bucket
      # on the same vendor. A grant is one caller the way a secret key is.
      it 'counts a delegated grant against a bucket of its own' do
        application = store.oauth_applications.create!(name: 'Probe', redirect_uri: 'https://example.test/cb',
                                                       confidential: false)
        token = Spree::OauthAccessToken.create!(
          application: application, resource_owner: admin_user, scopes: 'read_settings',
          expires_in: 3600, resource: 'http://test.host/api/v3/admin'
        )
        request.headers['Authorization'] = "Bearer #{token.plaintext_token}"
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        expect(Rails.cache).to have_received(:increment)
          .with("rate-limit:api_v3:oauth:#{token.id}", 1, expires_in: 60.seconds)
      end

      # A bearer value that resolves to no grant must not earn a bucket of
      # its own, or a flood of invented tokens would escape the address
      # bucket entirely.
      it 'keeps an unknown bearer token in the address bucket' do
        request.headers['Authorization'] = 'Bearer not-a-grant'
        allow(Rails.cache).to receive(:increment).and_return(1)

        get :index

        expect(Rails.cache).to have_received(:increment)
          .with('rate-limit:api_v3:0.0.0.0', 1, expires_in: 60.seconds)
      end
    end
  end

  describe 'rate limit configuration' do
    it 'exposes rate_limit_per_key as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_per_key]).to eq(300)
    end

    it 'exposes rate_limit_per_secret_key as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_per_secret_key]).to eq(600)
    end

    it 'exposes rate_limit_login as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_login]).to eq(5)
    end

    it 'exposes rate_limit_register as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_register]).to eq(3)
    end

    it 'exposes rate_limit_refresh as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_refresh]).to eq(10)
    end

    it 'exposes rate_limit_window as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_window]).to eq(60)
    end

    it 'allows overriding rate limit values' do
      original = Spree::Api::Config[:rate_limit_per_key]
      Spree::Api::Config[:rate_limit_per_key] = 500
      expect(Spree::Api::Config[:rate_limit_per_key]).to eq(500)
    ensure
      Spree::Api::Config[:rate_limit_per_key] = original
    end
  end
end

RSpec.describe Spree::Api::V3::Store::CountriesController, 'rate limit headers', type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:bucket_cache_key) { "rate-limit:api_v3:#{api_key.token}:0.0.0.0" }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  it 'skips rate limit headers when cache has no counter' do
    get :index

    expect(response.headers['X-RateLimit-Limit']).to be_nil
    expect(response.headers['X-RateLimit-Remaining']).to be_nil
    expect(response.headers['Retry-After']).to be_nil
  end

  it 'sets X-RateLimit-Limit and X-RateLimit-Remaining headers' do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read).with(bucket_cache_key).and_return(5)

    get :index

    expect(response.headers['X-RateLimit-Limit']).to eq(Spree::Api::Config[:rate_limit_per_key].to_s)
    expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(Spree::Api::Config[:rate_limit_per_key] - 5)
  end

  it 'does not set Retry-After header when under the limit' do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read).with(bucket_cache_key).and_return(5)

    get :index

    expect(response.headers['Retry-After']).to be_nil
  end

  it 'decreases X-RateLimit-Remaining based on request count' do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read).with(bucket_cache_key).and_return(10)

    get :index

    expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(Spree::Api::Config[:rate_limit_per_key] - 10)
  end

  it 'sets Retry-After when limit is reached' do
    limit = Spree::Api::Config[:rate_limit_per_key]
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read).with(bucket_cache_key).and_return(limit)

    get :index

    expect(response.headers['Retry-After']).to eq(Spree::Api::Config[:rate_limit_window].to_s)
    expect(response.headers['X-RateLimit-Remaining']).to eq('0')
  end
end
