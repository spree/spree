require 'spec_helper'

describe 'Platform API v2 Webhooks Subscribers spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:type) { 'subscriber' }
  let(:url) { 'https://www.mysite.com/spree_webhooks' }

  describe '#index' do
    context 'filtering' do
      let(:data_ids) { json_response['data'].pluck(:id) } 

      context 'with no params' do
        before do
          create_list(:subscriber, 2)
          get "/api/v2/platform/webhooks/subscribers", headers: bearer_token
        end

        it_behaves_like 'returns 200 HTTP status'

        it 'returns all subscribers' do
          expect(json_response['data'].count).to eq(2)
          expect(json_response['data'].first).to have_type(type)
          expect(json_response['data'].second).to have_type(type)
        end
      end

      context 'by active' do
        let!(:subscriber_active) { create(:subscriber, :active) }
        let!(:subscriber_inactive) { create(:subscriber, :inactive) }

        before { get "/api/v2/platform/webhooks/subscribers?filter[active_eq]=#{active}", headers: bearer_token }

        context 'active' do
          let(:active) { true }
          let(:active_subscribers) { Spree::Webhooks::Subscriber.active }

          it 'returns only active subscribers' do
            expect(json_response['data'].count).to eq(active_subscribers.count)
            expect(data_ids).not_to include(subscriber_inactive.id)
            expect(data_ids).to match_array(active_subscribers.ids.map(&:to_s))
          end
        end

        context 'inactive' do
          let(:active) { false }
          let(:inactive_subscribers) { Spree::Webhooks::Subscriber.inactive }

          it 'returns only active subscribers' do
            expect(json_response['data'].count).to eq(inactive_subscribers.count)
            expect(data_ids).not_to include(subscriber_active.id)
            expect(data_ids).to match_array(inactive_subscribers.ids.map(&:to_s))
          end
        end
      end

      context 'by url' do
        let!(:subscriber) { create(:subscriber, url: url) }
        let!(:another_subscriber) { create(:subscriber, url: 'http://localhost/') }

        before { get "/api/v2/platform/webhooks/subscribers?filter[url_cont]=spree_webhooks", headers: bearer_token }

        context 'matching the given term' do
          it 'returns subscribers only for the given url' do
            expect(json_response['data'].count).to eq(1)
            expect(data_ids).not_to include(another_subscriber.id)
            expect(data_ids).to match_array([subscriber.id.to_s])
          end
        end
      end
    end
  end

  context '#create' do
    let(:active) { true }
    let(:events) { ['order.created', 'order.placed', 'product.updated'] }
    let(:params) { { subscriber: { active: true, url: url, subscriptions: events } } }

    it 'returns status created' do
      post '/api/v2/platform/webhooks/subscribers', headers: bearer_token, params: params
      expect(response).to have_http_status :created
    end

    it 'creates a subscriber' do
      expect {
        post '/api/v2/platform/webhooks/subscribers', headers: bearer_token, params: params
      }.to change {
        Spree::Webhooks::Subscriber.
          all.
          as_json(except: %i[created_at id preferences updated_at]).
          map(&:values)
      }.from([]).to([[url, active, events]])
    end
  end
end
