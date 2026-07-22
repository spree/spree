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
        'avg_order_value', 'display_avg_order_value', 'avg_order_value_growth',
        'units_sold', 'units_growth',
        'customers_count', 'customers_growth'
      )
    end

    it 'returns chart_data as an array' do
      subject
      expect(json_response['chart_data']).to be_an(Array)
      expect(json_response['chart_data'].length).to eq(31) # default 30 days + today
    end

    it 'returns chart_data entries with current and previous period metrics' do
      subject
      entry = json_response['chart_data'].first
      expect(entry.keys).to match_array(
        %w[date previous_date sales orders avg_order_value units customers
           previous_sales previous_orders previous_avg_order_value previous_units previous_customers]
      )
    end

    it 'returns top_products as an array' do
      subject
      expect(json_response['top_products']).to be_an(Array)
    end

    it 'returns currency and both date ranges' do
      subject
      expect(json_response['currency']).to eq(store.default_currency)
      expect(json_response['date_from']).to be_present
      expect(json_response['date_to']).to be_present
      expect(json_response['previous_date_from']).to be_present
      expect(json_response['previous_date_to']).to be_present
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

      it 'counts units sold and distinct customers' do
        subject
        expected_units = order1.line_items.sum(:quantity) + order2.line_items.sum(:quantity)
        expect(json_response['summary']['units_sold']).to eq(expected_units)
        expect(json_response['summary']['customers_count']).to eq(2)
      end

      it 'returns nil growth when the previous period has no data' do
        subject
        expect(json_response['summary']['sales_growth']).to be_nil
        expect(json_response['summary']['orders_growth']).to be_nil
      end

      it 'includes orders in chart_data on their completed dates' do
        subject
        chart = json_response['chart_data']
        day_with_order = chart.find { |d| d['date'] == 5.days.ago.to_date.to_s }
        expect(day_with_order['orders']).to be >= 1
        expect(day_with_order['sales']).to be > 0
        expect(day_with_order['units']).to be > 0
        expect(day_with_order['customers']).to be >= 1
      end

      it 'returns top products from line items' do
        subject
        expect(json_response['top_products'].length).to be >= 1

        top = json_response['top_products'].first
        expect(top).to include('id', 'name', 'slug', 'quantity', 'amount', 'total', 'growth')
        expect(top['id']).to start_with('prod_')
        expect(top['quantity']).to be > 0
        expect(top['growth']).to be_nil # no previous period sales for this product
      end
    end

    context 'with custom date range' do
      it 'accepts date_from and date_to params' do
        get :analytics, params: { date_from: 7.days.ago.to_s, date_to: Time.current.to_s }, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['chart_data'].length).to be_between(7, 8)
      end
    end

    context 'with a channel filter' do
      let(:channel) { create(:channel, store: store) }
      let(:other_channel) { create(:channel, store: store) }
      let!(:channel_order) do
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 5.days.ago)
      end
      let!(:other_order) do
        create(:completed_order_with_totals, store: store, channel: other_channel, completed_at: 5.days.ago)
      end

      it 'scopes metrics to the requested channel' do
        get :analytics, params: { channel_id: channel.prefixed_id }, as: :json
        expect(json_response['channel_id']).to eq(channel.prefixed_id)
        expect(json_response['summary']['orders_count']).to eq(1)
        expect(json_response['summary']['sales_total']).to eq(channel_order.total.to_f.round(2))
      end

      it 'includes all channels when the param is omitted' do
        subject
        expect(json_response['channel_id']).to be_nil
        expect(json_response['summary']['orders_count']).to eq(2)
      end

      it 'returns 404 for a channel from another store' do
        foreign_channel = create(:channel, store: create(:store))
        get :analytics, params: { channel_id: foreign_channel.prefixed_id }, as: :json
        expect(response).to have_http_status(:not_found)
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

      it 'exposes the previous period metrics on matching chart days' do
        subject
        entry = json_response['chart_data'].find { |d| d['previous_date'] == 35.days.ago.to_date.to_s }
        expect(entry).to be_present
        expect(entry['previous_orders']).to eq(1)
        expect(entry['previous_sales']).to be > 0
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

  describe 'GET #rankings' do
    subject { get :rankings, as: :json }

    it 'returns ok with empty rankings' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['customers']).to eq([])
      expect(json_response['categories']).to eq([])
    end

    context 'with completed orders' do
      let(:customer) { create(:user, first_name: 'Jane', last_name: 'Doe') }
      let(:taxon) { create(:taxon) }
      let!(:order) do
        create(:completed_order_with_totals, store: store, user: customer, email: customer.email, completed_at: 5.days.ago)
      end

      before do
        order.products.each { |product| product.taxons << taxon }
      end

      it 'returns top customers by revenue' do
        subject
        top = json_response['customers'].first
        expect(top['id']).to start_with('cus_')
        expect(top['email']).to eq(customer.email)
        expect(top['name']).to eq('Jane Doe')
        expect(top['orders_count']).to eq(1)
        expect(top['amount']).to eq(order.total.to_f.round(2))
        expect(top['display_amount']).to be_present
      end

      it 'returns top categories by revenue' do
        subject
        top = json_response['categories'].first
        expect(top['id']).to start_with('ctg_')
        expect(top['name']).to eq(taxon.name)
        expect(top['quantity']).to be > 0
        expect(top['amount']).to be > 0
        expect(top['display_amount']).to be_present
      end
    end

    context 'with more customers than the limit' do
      before do
        3.times { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }
      end

      it 'respects the limit param' do
        get :rankings, params: { limit: 2 }, as: :json
        expect(json_response['customers'].length).to eq(2)
      end
    end

    context 'with a channel filter' do
      let(:channel) { create(:channel, store: store) }
      let!(:channel_order) do
        create(:completed_order_with_totals, store: store, channel: channel, completed_at: 5.days.ago)
      end
      let!(:other_order) { create(:completed_order_with_totals, store: store, completed_at: 5.days.ago) }

      it 'ranks only the requested channel' do
        get :rankings, params: { channel_id: channel.prefixed_id }, as: :json
        expect(json_response['channel_id']).to eq(channel.prefixed_id)
        expect(json_response['customers'].length).to eq(1)
        expect(json_response['customers'].first['email']).to eq(channel_order.email)
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

  describe 'GET #operations' do
    subject { get :operations, as: :json }

    it 'returns all counters' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response).to include(
        'low_stock_threshold', 'orders_to_fulfill', 'payments_to_collect',
        'open_returns', 'low_stock_items', 'out_of_stock_items'
      )
    end

    context 'with actionable orders' do
      let!(:ready_order) { create(:order_ready_to_ship, store: store) }
      let!(:balance_due_order) do
        create(:completed_order_with_totals, store: store, payment_state: 'balance_due', shipment_state: 'shipped')
      end

      it 'counts orders to fulfill and payments to collect' do
        subject
        expect(json_response['orders_to_fulfill']).to eq(1)
        expect(json_response['payments_to_collect']).to eq(1)
      end

      it 'scopes order counts to the requested channel' do
        channel = create(:channel, store: store)
        create(:order_ready_to_ship, store: store, channel: channel)

        get :operations, params: { channel_id: channel.prefixed_id }, as: :json
        expect(json_response['channel_id']).to eq(channel.prefixed_id)
        expect(json_response['orders_to_fulfill']).to eq(1)
        expect(json_response['payments_to_collect']).to eq(0)
      end
    end

    context 'with an open return' do
      let!(:return_authorization) { create(:return_authorization) }

      it 'counts authorized return authorizations' do
        subject
        expect(json_response['open_returns']).to eq(1)
      end
    end

    context 'with stock levels' do
      let!(:low_stock_product) { create(:product, store: store) }
      let!(:out_of_stock_product) { create(:product, store: store) }

      before do
        low_stock_product.master.stock_items.first.set_count_on_hand(3)
      end

      it 'counts low stock and out of stock variants' do
        subject
        expect(json_response['low_stock_items']).to eq(1)
        expect(json_response['out_of_stock_items']).to eq(1)
      end

      it 'respects the low_stock_threshold param' do
        get :operations, params: { low_stock_threshold: 2 }, as: :json
        expect(json_response['low_stock_threshold']).to eq(2)
        expect(json_response['low_stock_items']).to eq(0)
      end

      it 'ignores variants that do not track inventory' do
        low_stock_product.master.update!(track_inventory: false)
        out_of_stock_product.master.update!(track_inventory: false)
        subject
        expect(json_response['low_stock_items']).to eq(0)
        expect(json_response['out_of_stock_items']).to eq(0)
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
