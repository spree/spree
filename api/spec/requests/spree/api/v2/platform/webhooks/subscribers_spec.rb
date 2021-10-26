require 'spec_helper'

describe 'Platform API v2 Webhooks Subscribers spec', type: :request do
  subject { post '/api/v2/platform/webhooks/subscribers', headers: bearer_token, params: params }

  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:active) { true }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:events) { ['order.create', 'order.complete', 'product.update'] }
  let(:params) { { subscriber: { active: true, url: url, subscriptions: events } } }
  let(:url) { 'https://www.url.com/' }

  context 'valid request' do
    it 'returns status created' do
      subject
      expect(response).to have_http_status :created
    end

    it 'creates a subscriber' do
      expect { subject }.to(
        change { Spree::Webhooks::Subscriber.count }.from(0).to(1).and(
          change { Spree::Webhooks::Subscriber.pluck(:active, :url, :subscriptions) }.
            from([]).
            to([[active, url, events]])
        )
      )
    end
  end
end
