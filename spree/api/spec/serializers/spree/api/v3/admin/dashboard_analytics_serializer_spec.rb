require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DashboardAnalyticsSerializer do
  let(:store) { @default_store }
  let(:currency) { store.default_currency }
  let(:time_range) { 30.days.ago.beginning_of_day..Time.current.end_of_day }
  let(:params) do
    {
      store: store,
      locale: 'en',
      currency: currency,
      user: nil,
      includes: [],
      expand: []
    }
  end

  subject { described_class.new(store: store, currency: currency, time_range: time_range, params: params) }

  describe '#to_h' do
    let(:result) { subject.to_h }

    it 'returns currency and date range' do
      expect(result[:currency]).to eq(currency)
      expect(result[:date_from]).to be_present
      expect(result[:date_to]).to be_present
    end

    it 'returns summary with all expected keys' do
      expect(result[:summary]).to include(
        :sales_total, :display_sales_total, :sales_growth,
        :orders_count, :orders_growth,
        :avg_order_value, :display_avg_order_value, :avg_order_value_growth
      )
    end

    it 'returns chart_data covering the full date range' do
      expected_days = (time_range.first.to_date..time_range.last.to_date).count
      expect(result[:chart_data].length).to eq(expected_days)
    end

    it 'returns chart_data entries with correct keys' do
      entry = result[:chart_data].first
      expect(entry.keys).to match_array(%i[date sales orders avg_order_value])
    end

    it 'returns top_products as an array' do
      expect(result[:top_products]).to be_an(Array)
    end

    context 'with no orders' do
      it 'returns zero summary values' do
        expect(result[:summary][:sales_total]).to eq(0.0)
        expect(result[:summary][:orders_count]).to eq(0)
        expect(result[:summary][:avg_order_value]).to eq(0.0)
        expect(result[:summary][:sales_growth]).to eq(0.0)
      end

      it 'returns empty top_products' do
        expect(result[:top_products]).to eq([])
      end

      it 'returns zero values in chart_data' do
        result[:chart_data].each do |entry|
          expect(entry[:sales]).to eq(0.0)
          expect(entry[:orders]).to eq(0)
          expect(entry[:avg_order_value]).to eq(0.0)
        end
      end
    end

    context 'with completed orders' do
      let!(:order1) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:order2) { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

      it 'calculates sales total' do
        expected = (order1.total + order2.total).to_f.round(2)
        expect(result[:summary][:sales_total]).to eq(expected)
      end

      it 'counts orders' do
        expect(result[:summary][:orders_count]).to eq(2)
      end

      it 'calculates avg order value' do
        expected = ((order1.total + order2.total) / 2.0).round(2)
        expect(result[:summary][:avg_order_value]).to eq(expected)
      end

      it 'formats display values as money strings' do
        expect(result[:summary][:display_sales_total]).to include('$')
        expect(result[:summary][:display_avg_order_value]).to include('$')
      end

      it 'populates chart_data on order dates' do
        day = result[:chart_data].find { |d| d[:date] == 5.days.ago.to_date.to_s }
        expect(day[:orders]).to be >= 1
        expect(day[:sales]).to be > 0
      end

      it 'returns top products with serialized fields' do
        expect(result[:top_products].length).to be >= 1
        top = result[:top_products].first
        expect(top[:id]).to start_with('prod_').or be_present
        expect(top[:name]).to be_present
        expect(top[:quantity]).to be > 0
        expect(top[:total]).to include('$')
      end
    end

    context 'with growth rate calculation' do
      let!(:recent_order) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      let!(:older_order) { create(:completed_order_with_totals, store: store, completed_at: 35.days.ago) }

      it 'calculates non-zero growth rates when both periods have data' do
        expect(result[:summary][:sales_growth]).to be_a(Numeric)
        expect(result[:summary][:orders_growth]).to be_a(Numeric)
      end
    end

    context 'with custom 7-day range' do
      let(:time_range) { 7.days.ago.beginning_of_day..Time.current.end_of_day }

      it 'returns chart_data for 7-8 days' do
        expect(result[:chart_data].length).to be_between(7, 8)
      end
    end
  end
end
