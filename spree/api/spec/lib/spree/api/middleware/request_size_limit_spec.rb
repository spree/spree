require 'spec_helper'

RSpec.describe Spree::Api::Middleware::RequestSizeLimit do
  let(:app) { ->(env) { [200, { 'Content-Type' => 'application/json' }, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  def env_for(path, content_length: 0)
    {
      'PATH_INFO' => path,
      'CONTENT_LENGTH' => content_length.to_s,
      'REQUEST_METHOD' => 'POST'
    }
  end

  describe '#call' do
    context 'API v3 requests' do
      it 'allows requests within the size limit' do
        status, _headers, _body = middleware.call(env_for('/api/v3/store/cart', content_length: 1024))

        expect(status).to eq(200)
      end

      it 'rejects requests exceeding the size limit' do
        large_size = Spree::Api::Config[:max_request_body_size] + 1
        status, headers, body = middleware.call(env_for('/api/v3/store/cart', content_length: large_size))

        expect(status).to eq(413)
        expect(headers['Content-Type']).to eq('application/json')

        parsed = JSON.parse(body.first)
        expect(parsed['error']['code']).to eq('request_too_large')
        expect(parsed['error']['message']).to be_present
      end

      it 'allows requests exactly at the limit' do
        exact_size = Spree::Api::Config[:max_request_body_size]
        status, _headers, _body = middleware.call(env_for('/api/v3/store/cart', content_length: exact_size))

        expect(status).to eq(200)
      end

      it 'respects custom limit passed via constructor' do
        custom_middleware = described_class.new(app, limit: 500)

        status, _headers, _body = custom_middleware.call(env_for('/api/v3/store/cart', content_length: 501))
        expect(status).to eq(413)

        status, _headers, _body = custom_middleware.call(env_for('/api/v3/store/cart', content_length: 500))
        expect(status).to eq(200)
      end
    end

    context 'non-API requests' do
      it 'does not limit requests to other paths' do
        status, _headers, _body = middleware.call(env_for('/admin/products', content_length: 10_000_000))

        expect(status).to eq(200)
      end
    end

    context 'requests without Content-Length' do
      it 'allows requests with no Content-Length header' do
        env = { 'PATH_INFO' => '/api/v3/store/cart', 'REQUEST_METHOD' => 'GET' }
        status, _headers, _body = middleware.call(env)

        expect(status).to eq(200)
      end
    end
  end
end
