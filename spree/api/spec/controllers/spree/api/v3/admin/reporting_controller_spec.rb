require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ReportingController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'POST #query' do
    it 'hydrates enumerated dimensions with labels' do
      create(:completed_order_with_totals, store: store, completed_at: 2.days.ago).update_columns(payment_status: 'partially_paid')

      post :query, params: { metrics: %w[orders], dimensions: %w[payment_status] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['rows'].first['dimensions']['payment_status']).to eq('id' => 'partially_paid', 'label' => 'Partially paid', 'meta' => {})
    end

    subject { post :query, params: query_params, as: :json }

    let(:query_params) do
      {
        metrics: %w[total_sales orders average_order_value],
        dimensions: [{ name: 'completed_at', grain: 'day' }],
        compare: 'previous_period'
      }
    end

    it 'returns ok with totals, rows and meta' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['meta']).to include('currency', 'time_range', 'previous_time_range', 'metrics', 'dimensions')
      expect(json_response['totals'].keys).to match_array(%w[total_sales orders average_order_value])
      expect(json_response['rows'].length).to eq(31) # default 30 days + today
    end

    context 'with completed orders' do
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'computes totals with money display strings and nil growth without baseline' do
        subject
        totals = json_response['totals']
        expected_gross = (order1.total + order2.total).to_f.round(2)

        expect(totals['total_sales']['value']).to eq(expected_gross)
        expect(totals['total_sales']['display']).to include('$')
        expect(totals['total_sales']['growth']).to be_nil
        expect(totals['orders']['value']).to eq(2)
        expect(totals['average_order_value']['value']).to eq((expected_gross / 2).round(2))
      end

      it 'hydrates product rows with prefixed ids, labels and meta' do
        post :query, params: {
          metrics: %w[net_sales units_sold],
          dimensions: %w[product],
          sort: '-net_sales',
          limit: 5
        }, as: :json

        row = json_response['rows'].first
        expect(row['dimensions']['product']['id']).to start_with('prod_')
        expect(row['dimensions']['product']['label']).to be_present
        expect(row['dimensions']['product']['meta']).to include('slug', 'thumbnail_url')
        expect(row['metrics']['net_sales']['value']).to be > 0
      end

      it 'hydrates customer rows and ranks by revenue' do
        post :query, params: {
          metrics: %w[total_sales orders],
          dimensions: %w[customer],
          sort: '-total_sales',
          limit: 5
        }, as: :json

        expect(json_response['rows'].length).to eq(2)
        top = json_response['rows'].first
        expect(top['dimensions']['customer']['id']).to start_with('cust_')
        expect(top['dimensions']['customer']['meta']['email']).to be_present
        expect(top['metrics']['orders']['value']).to eq(1)
      end

      it 'filters by channel' do
        channel = create(:channel, store: store)
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 3.days.ago)

        post :query, params: {
          metrics: %w[orders],
          filters: [{ dimension: 'channel', op: 'eq', value: channel.prefixed_id }]
        }, as: :json

        expect(json_response['totals']['orders']['value']).to eq(1)
      end

      # The endpoint slices the payload against an allowlist, so a contract key
      # missing from it would be dropped and the caller would get unfiltered
      # rows back with no error at all.
      it 'applies metric filters sent by a client' do
        create(:completed_order_with_totals, store: store, completed_at: 3.days.ago)

        post :query, params: {
          metrics: %w[units_sold],
          dimensions: %w[product],
          metric_filters: [{ metric: 'units_sold', op: 'gt', value: 10_000 }]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['rows']).to be_empty
        expect(json_response['totals']['units_sold']['value']).to be > 0
      end

      it 'returns 404 for a channel filter from another store' do
        foreign_channel = create(:channel, store: create(:store))

        post :query, params: {
          metrics: %w[orders],
          filters: [{ dimension: 'channel', op: 'eq', value: foreign_channel.prefixed_id }]
        }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an invalid query' do
      it 'rejects unknown members with the standard v3 error shape' do
        post :query, params: { metrics: %w[revenues] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('invalid_reporting_query')
        expect(json_response['error']['message']).to include('net_sales')
      end
      it 'names the valid members in the error details so a client can correct itself' do
        post :query, params: { metrics: %w[revenue] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        details = json_response['error']['details']
        expect(details['kind']).to eq('metric')
        expect(details['name']).to eq('revenue')
        expect(details['valid']).to include('total_sales', 'net_sales')
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

  describe 'secret key member scopes' do
    let(:headers) { { 'x-spree-api-key' => reports_key.plaintext_token } }
    let(:reports_key) { create(:api_key, :secret, store: store, scopes: %w[read_reports]) }

    it 'allows order-data queries with read_reports alone' do
      post :query, params: { metrics: %w[total_sales orders] }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'forbids members whose key_scope the key lacks' do
      post :query, params: { metrics: %w[net_sales], dimensions: %w[product] }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['details']['required_scopes']).to eq(%w[read_products])
    end

    it 'allows members once the key carries their scope' do
      key = create(:api_key, :secret, store: store, scopes: %w[read_reports read_products])
      request.headers['x-spree-api-key'] = key.plaintext_token

      post :query, params: { metrics: %w[net_sales], dimensions: %w[product] }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'member-level permissions' do
    include_context 'API v3 Admin with custom permissions'

    # Reporting + order data, but no product/category/customer keys.
    let(:custom_permissions) { %w[read_reports read_orders] }

    it 'allows order-data queries' do
      post :query, params: { metrics: %w[total_sales orders] }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'forbids dimensions whose subject the role cannot read' do
      post :query, params: { metrics: %w[net_sales], dimensions: %w[product] }, as: :json
      expect(response).to have_http_status(:forbidden)

      post :query, params: { metrics: %w[total_sales], dimensions: %w[customer] }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids filters whose subject the role cannot read' do
      post :query, params: {
        metrics: %w[net_sales],
        filters: [{ dimension: 'product', op: 'eq', value: 'prod_x' }]
      }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET #schema' do
    it 'returns the self-describing contract' do
      get :schema, as: :json

      expect(response).to have_http_status(:ok)
      metric = json_response['metrics'].find { |m| m['name'] == 'total_sales' }
      expect(metric).to include('label', 'description', 'format', 'currency')
      dimension = json_response['dimensions'].find { |d| d['name'] == 'completed_at' }
      expect(dimension['grains']).to include('day', 'week', 'month')
      expect(json_response['time_range']['presets']).to be_present
      expect(json_response['meta']).to include('currency', 'timezone')
    end

    it 'omits members a secret key cannot reference' do
      key = create(:api_key, :secret, store: store, scopes: %w[read_reports])
      request.headers['x-spree-api-key'] = key.plaintext_token
      request.headers['Authorization'] = nil

      get :schema, as: :json
      names = json_response['dimensions'].map { |d| d['name'] }
      expect(names).to include('channel', 'completed_at')
      expect(names).not_to include('product', 'customer', 'category')
    end

    context 'for a limited staff role' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permissions) { %w[read_reports read_orders] }

      it 'omits dimensions whose subject the role cannot read' do
        get :schema, as: :json
        names = json_response['dimensions'].map { |d| d['name'] }
        expect(names).to include('channel', 'market', 'country')
        expect(names).not_to include('product', 'customer')
      end
    end
  end
end
