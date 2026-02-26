require 'spec_helper'

RSpec.describe 'Rate Limiting', type: :controller do
  describe Spree::Api::V3::Store::StoresController do
    controller(Spree::Api::V3::Store::StoresController) {}

    render_views

    include_context 'API v3 Store'

    before do
      request.headers['X-Spree-Api-Key'] = api_key.token
    end

    describe 'rate limit response format' do
      it 'returns JSON error with rate_limit_exceeded code' do
        response_proc = Spree::Api::V3::Store::BaseController::RATE_LIMIT_RESPONSE
        status, headers, body = response_proc.call

        expect(status).to eq(429)
        expect(headers['Content-Type']).to eq('application/json')
        expect(headers['Retry-After']).to eq('60')

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

    it 'allows overriding rate limit values' do
      original = Spree::Api::Config[:rate_limit_per_key]
      Spree::Api::Config[:rate_limit_per_key] = 500
      expect(Spree::Api::Config[:rate_limit_per_key]).to eq(500)
    ensure
      Spree::Api::Config[:rate_limit_per_key] = original
    end
  end
end
