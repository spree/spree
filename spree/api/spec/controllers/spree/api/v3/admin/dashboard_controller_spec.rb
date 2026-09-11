require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DashboardController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #counters' do
    subject { get :counters, as: :json }

    let(:counter_keys) { json_response['counters'].map { |counter| counter['key'] } }

    it 'returns every registered counter as a key, a number and where it leads' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['channel_id']).to be_nil
      expect(counter_keys).to eq(
        %w[orders_to_fulfill payments_to_collect open_returns open_exchanges open_claims low_stock_items out_of_stock_items]
      )

      fulfill = json_response['counters'].first
      expect(fulfill).to include('value' => 0, 'nav' => 'orders')
      # The dashboard translates the key in its own locale, so no copy ships.
      expect(fulfill.keys).to match_array(%w[key value link nav])
      expect(fulfill['link']).to eq(
        'resource' => 'orders',
        'filters' => [{ 'field' => 'fulfillment_status', 'operator' => 'eq', 'value' => 'unfulfilled' }]
      )
    end

    it 'scopes order counts to the requested channel' do
      channel = create(:channel, store: store)
      create(:order_ready_to_ship, store: store)
      create(:order_ready_to_ship, store: store, channel: channel)

      get :counters, params: { channel_id: channel.prefixed_id }, as: :json

      expect(json_response['channel_id']).to eq(channel.prefixed_id)
      expect(json_response['counters'].find { |c| c['key'] == 'orders_to_fulfill' }['value']).to eq(1)
    end

    it 'names the sidebar entry a post-sale counter badges' do
      subject

      returns = json_response['counters'].find { |counter| counter['key'] == 'open_returns' }
      expect(returns['nav']).to eq('returns')
    end

    it 'refuses a channel from another store' do
      other_channel = create(:channel, store: create(:store))

      get :counters, params: { channel_id: other_channel.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    context 'via a secret key' do
      let(:headers) { { 'x-spree-api-key' => key.plaintext_token } }
      let(:key) { create(:api_key, :secret, store: store, scopes: scopes) }

      context 'with the dashboard scope alone' do
        let(:scopes) { %w[read_dashboard] }

        it 'returns an empty list rather than counters over data the key cannot read' do
          subject
          expect(response).to have_http_status(:ok)
          expect(counter_keys).to be_empty
        end
      end

      context 'with the scopes some counters require' do
        let(:scopes) { %w[read_dashboard read_stock] }

        it 'returns only those counters' do
          subject
          expect(counter_keys).to eq(%w[low_stock_items out_of_stock_items])
        end
      end
    end

    context 'for a staff role without order access' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permissions) { %w[read_dashboard read_stock] }

      it 'returns only the stock counters' do
        subject
        expect(response).to have_http_status(:ok)
        expect(counter_keys).to eq(%w[low_stock_items out_of_stock_items])
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
