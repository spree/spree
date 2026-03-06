require 'spec_helper'

RSpec.describe 'Rate Limiting', type: :controller do
  describe Spree::Api::V3::Store::CountriesController do
    controller(Spree::Api::V3::Store::CountriesController) {}

    render_views

    include_context 'API v3 Store'

    before do
      request.headers['X-Spree-Api-Key'] = api_key.token
    end

    describe 'rate limit response format' do
      it 'returns JSON error with rate_limit_exceeded code' do
        response_proc = Spree::Api::V3::BaseController::RATE_LIMIT_RESPONSE
        status, headers, body = response_proc.call

        expect(status).to eq(429)
        expect(headers['Content-Type']).to eq('application/json')
        expect(headers['Retry-After']).to eq(Spree::Api::Config[:rate_limit_window].to_s)
        expect(headers['X-RateLimit-Limit']).to eq(Spree::Api::Config[:rate_limit_per_key].to_s)
        expect(headers['X-RateLimit-Remaining']).to eq('0')

        parsed = JSON.parse(body.first)
        expect(parsed['error']['code']).to eq('rate_limit_exceeded')
        expect(parsed['error']['message']).to be_present
      end
    end
  end

  describe 'rate limit configuration' do
    it 'exposes rate_limit_per_key as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_per_key]).to eq(300)
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

    it 'exposes rate_limit_oauth as a configurable preference' do
      expect(Spree::Api::Config[:rate_limit_oauth]).to eq(5)
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
    allow(Rails.cache).to receive(:read)
      .with("rate-limit:spree/api/v3/store/countries:#{api_key.token}")
      .and_return(5)

    get :index

    expect(response.headers['X-RateLimit-Limit']).to eq(Spree::Api::Config[:rate_limit_per_key].to_s)
    expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(Spree::Api::Config[:rate_limit_per_key] - 5)
  end

  it 'does not set Retry-After header when under the limit' do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read)
      .with("rate-limit:spree/api/v3/store/countries:#{api_key.token}")
      .and_return(5)

    get :index

    expect(response.headers['Retry-After']).to be_nil
  end

  it 'decreases X-RateLimit-Remaining based on request count' do
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read)
      .with("rate-limit:spree/api/v3/store/countries:#{api_key.token}")
      .and_return(10)

    get :index

    expect(response.headers['X-RateLimit-Remaining'].to_i).to eq(Spree::Api::Config[:rate_limit_per_key] - 10)
  end

  it 'sets Retry-After when limit is reached' do
    limit = Spree::Api::Config[:rate_limit_per_key]
    allow(Rails.cache).to receive(:read).and_call_original
    allow(Rails.cache).to receive(:read)
      .with("rate-limit:spree/api/v3/store/countries:#{api_key.token}")
      .and_return(limit)

    get :index

    expect(response.headers['Retry-After']).to eq(Spree::Api::Config[:rate_limit_window].to_s)
    expect(response.headers['X-RateLimit-Remaining']).to eq('0')
  end
end
