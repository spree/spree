require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DashboardController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #analytics' do
    subject { get :analytics, as: :json }

    it 'returns ok' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'returns summary stats' do
      subject
      expect(json_response['summary']).to include(
        'sales_total', 'display_sales_total', 'sales_growth',
        'orders_count', 'orders_growth',
        'avg_order_value', 'display_avg_order_value', 'avg_order_value_growth'
      )
    end

    it 'returns chart_data as an array' do
      subject
      expect(json_response['chart_data']).to be_an(Array)
      expect(json_response['chart_data'].length).to eq(31) # default 30 days + today
    end

    it 'returns chart_data entries with date, sales, orders, avg_order_value' do
      subject
      entry = json_response['chart_data'].first
      expect(entry.keys).to match_array(%w[date sales orders avg_order_value])
    end

    it 'returns top_products as an array' do
      subject
      expect(json_response['top_products']).to be_an(Array)
    end

    it 'returns currency and date range' do
      subject
      expect(json_response['currency']).to eq(store.default_currency)
      expect(json_response['date_from']).to be_present
      expect(json_response['date_to']).to be_present
    end

    context 'with completed orders' do
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'calculates sales total from completed orders' do
        subject
        expected_total = (order1.total + order2.total).to_f.round(2)
        expect(json_response['summary']['sales_total']).to eq(expected_total)
      end

      it 'counts orders' do
        subject
        expect(json_response['summary']['orders_count']).to eq(2)
      end

      it 'calculates average order value' do
        subject
        expected_avg = ((order1.total + order2.total) / 2.0).round(2)
        expect(json_response['summary']['avg_order_value']).to eq(expected_avg)
      end

      it 'includes orders in chart_data on their completed dates' do
        subject
        chart = json_response['chart_data']
        day_with_order = chart.find { |d| d['date'] == 5.days.ago.to_date.to_s }
        expect(day_with_order['orders']).to be >= 1
        expect(day_with_order['sales']).to be > 0
      end

      it 'returns top products from line items' do
        subject
        expect(json_response['top_products'].length).to be >= 1

        top = json_response['top_products'].first
        expect(top).to include('id', 'name', 'slug', 'quantity', 'total')
        expect(top['id']).to start_with('prod_')
        expect(top['quantity']).to be > 0
      end
    end

    context 'with custom date range' do
      it 'accepts date_from and date_to params' do
        get :analytics, params: { date_from: 7.days.ago.to_s, date_to: Time.current.to_s }, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['chart_data'].length).to be_between(7, 8)
      end
    end

    context 'with growth rate calculation' do
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:older_order) { create(:completed_order_with_totals, store: store, completed_at: 35.days.ago) }

      it 'calculates growth rates compared to previous period' do
        subject
        # Recent period has orders, previous period also has orders
        expect(json_response['summary']['sales_growth']).to be_a(Numeric)
        expect(json_response['summary']['orders_growth']).to be_a(Numeric)
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
