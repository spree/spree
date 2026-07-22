require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ReportingController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'POST #query' do
    subject { post :query, params: query_params, as: :json }

    let(:query_params) do
      {
        metrics: %w[gross_revenue orders_count aov],
        dimensions: [{ name: 'completed_at', grain: 'day' }],
        compare: 'previous_period'
      }
    end

    it 'returns ok with totals, rows and meta' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['meta']).to include('currency', 'time_range', 'previous_time_range', 'metrics', 'dimensions')
      expect(json_response['totals'].keys).to match_array(%w[gross_revenue orders_count aov])
      expect(json_response['rows'].length).to eq(31) # default 30 days + today
    end

    context 'with completed orders' do
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'computes totals with money display strings and nil growth without baseline' do
        subject
        totals = json_response['totals']
        expected_gross = (order1.total + order2.total).to_f.round(2)

        expect(totals['gross_revenue']['value']).to eq(expected_gross)
        expect(totals['gross_revenue']['display']).to include('$')
        expect(totals['gross_revenue']['growth']).to be_nil
        expect(totals['orders_count']['value']).to eq(2)
        expect(totals['aov']['value']).to eq((expected_gross / 2).round(2))
      end

      it 'hydrates product rows with prefixed ids, labels and meta' do
        post :query, params: {
          metrics: %w[net_revenue units_sold],
          dimensions: %w[product],
          sort: '-net_revenue',
          limit: 5
        }, as: :json

        row = json_response['rows'].first
        expect(row['dimensions']['product']['id']).to start_with('prod_')
        expect(row['dimensions']['product']['label']).to be_present
        expect(row['dimensions']['product']['meta']).to include('slug', 'thumbnail_url')
        expect(row['metrics']['net_revenue']['value']).to be > 0
      end

      it 'hydrates customer rows and ranks by revenue' do
        post :query, params: {
          metrics: %w[gross_revenue orders_count],
          dimensions: %w[customer],
          sort: '-gross_revenue',
          limit: 5
        }, as: :json

        expect(json_response['rows'].length).to eq(2)
        top = json_response['rows'].first
        expect(top['dimensions']['customer']['id']).to start_with('cus_')
        expect(top['dimensions']['customer']['meta']['email']).to be_present
        expect(top['metrics']['orders_count']['value']).to eq(1)
      end

      it 'filters by channel' do
        channel = create(:channel, store: store)
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 3.days.ago)

        post :query, params: {
          metrics: %w[orders_count],
          filters: [{ dimension: 'channel', op: 'eq', value: channel.prefixed_id }]
        }, as: :json

        expect(json_response['totals']['orders_count']['value']).to eq(1)
      end

      it 'returns 404 for a channel filter from another store' do
        foreign_channel = create(:channel, store: create(:store))

        post :query, params: {
          metrics: %w[orders_count],
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
        expect(json_response['error']['message']).to include('net_revenue')
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

  describe 'member-level permissions' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permission_set) do
      Class.new(Spree::PermissionSets::Base) do
        def activate!
          can [:read, :admin], Spree::Order
          can [:read, :admin], Spree::LineItem
        end
      end
    end

    it 'allows order-data queries' do
      post :query, params: { metrics: %w[gross_revenue orders_count] }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'forbids dimensions whose subject the role cannot read' do
      post :query, params: { metrics: %w[net_revenue], dimensions: %w[product] }, as: :json
      expect(response).to have_http_status(:forbidden)

      post :query, params: { metrics: %w[gross_revenue], dimensions: %w[customer] }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids filters whose subject the role cannot read' do
      post :query, params: {
        metrics: %w[net_revenue],
        filters: [{ dimension: 'product', op: 'eq', value: 'prod_x' }]
      }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET #schema' do
    it 'returns the registry introspection payload' do
      get :schema, as: :json

      expect(response).to have_http_status(:ok)
      metric_names = json_response['metrics'].map { |m| m['name'] }
      expect(metric_names).to include('net_revenue', 'orders_count', 'aov')
      dimension = json_response['dimensions'].find { |d| d['name'] == 'completed_at' }
      expect(dimension['grains']).to include('day')
    end
  end
end
