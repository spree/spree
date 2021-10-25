require 'spec_helper'

describe 'Platform API v2 Webhooks Subscribers spec', type: :request do
  subject { post '/api/v2/platform/webhooks/subscribers', headers: bearer_token, params: params }

  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:params) { { subscriber: { active: true, url: 'https://www.url.com/', subscriptions: ['*'] } } }

  context 'valid request' do
    it 'returns status created' do
      subject
      expect(response).to have_http_status :created
    end

    it 'creates a subscriber ' do
      expect { subject }.to change { Spree::Webhooks::Subscriber.count }.from(0).to(1)
    end
  end
end
