require 'spec_helper'

describe 'Platform API v2 Webhooks Events spec', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:type) { 'event' }

  describe '#index' do
    context 'filtering' do
      let(:data_ids) { json_response['data'].pluck(:id) } 

      context 'with no params' do
        before do
          create_list(:event, 2)
          get "/api/v2/platform/webhooks/events", headers: bearer_token
        end

        it_behaves_like 'returns 200 HTTP status'

        it 'returns all events' do
          expect(json_response['data'].count).to eq(2)
          expect(json_response['data'].first).to have_type(type)
          expect(json_response['data'].second).to have_type(type)
        end
      end

      context 'by name' do
        let!(:event_1) { create(:event, name: name_filter) }
        let!(:event_2) { create(:event, name: 'order.created') }
        let(:name_filter) { 'order.canceled' }

        before { get "/api/v2/platform/webhooks/events?filter[name_eq]=#{name_filter}", headers: bearer_token }

        it 'returns only the event matching the given name' do
          expect(json_response['data'].count).to eq(1)
          expect(data_ids).not_to include(event_2.id)
          expect(data_ids).to match_array([event_1.id.to_s])
        end
      end

      context 'by request_errors' do
        let!(:event_1) { create(:event, :failed, request_errors: "[SPREE WEBHOOKS] 'order.canceled' can not make a request to 'http://google.com/'") }
        let!(:event_2) { create(:event, :successful) }

        before { get "/api/v2/platform/webhooks/events?filter[request_errors_cont]=google", headers: bearer_token }

        it 'returns only the event matching the given name' do
          expect(json_response['data'].count).to eq(1)
          expect(data_ids).not_to include(event_2.id)
          expect(data_ids).to match_array([event_1.id.to_s])
        end
      end

      context 'by response_code' do
        let!(:event_1) { create(:event, response_code: response_code_filter) }
        let!(:event_2) { create(:event, response_code: '301') }
        let(:response_code_filter) { '200' }

        before { get "/api/v2/platform/webhooks/events?filter[response_code_eq]=#{response_code_filter}", headers: bearer_token }

        it 'returns only the event matching the given name' do
          expect(json_response['data'].count).to eq(1)
          expect(data_ids).not_to include(event_2.id)
          expect(data_ids).to match_array([event_1.id.to_s])
        end
      end

      context 'by success' do
        let!(:event_success) { create(:event, :successful) }
        let!(:event_fail) { create(:event, :failed) }
        let(:success_filter) { true }

        before { get "/api/v2/platform/webhooks/events?filter[success_eq]=#{success_filter}", headers: bearer_token }

        it 'returns only the event matching the given name' do
          expect(json_response['data'].count).to eq(1)
          expect(data_ids).not_to include(event_fail.id)
          expect(data_ids).to match_array([event_success.id.to_s])
        end
      end

      context 'by url' do
        let!(:event_1) { create(:event, url: 'https://mysite.com/spree_webhooks') }
        let!(:event_2) { create(:event, url: 'http://localhost.com/') }
        let(:url_filter) { 'mysite' }

        before { get "/api/v2/platform/webhooks/events?filter[url_cont]=#{url_filter}", headers: bearer_token }

        it 'returns only the event matching the given name' do
          expect(json_response['data'].count).to eq(1)
          expect(data_ids).not_to include(event_2.id)
          expect(data_ids).to match_array([event_1.id.to_s])
        end
      end
    end
  end
end
