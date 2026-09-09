require 'spec_helper'

RSpec.describe Spree::Reporting::Schema do
  let(:store) { @default_store }

  subject(:schema) { described_class.new(store: store).to_h }

  it 'describes metrics with localized labels, formats and currency' do
    metric = schema[:metrics].find { |m| m[:name] == :total_sales }
    expect(metric[:label]).to eq('Total sales')
    expect(metric[:description]).to be_present
    expect(metric[:format]).to eq(:money)
    expect(metric[:currency]).to eq(store.default_currency)
  end

  it 'publishes compatible metrics, filter ops and enumerated values per dimension' do
    category = schema[:dimensions].find { |d| d[:name] == :category }
    expect(category[:compatible_metrics]).to include(:net_sales, :units_sold)
    expect(category[:compatible_metrics]).not_to include(:total_sales, :average_order_value)

    channel = schema[:dimensions].find { |d| d[:name] == :channel }
    expect(channel[:compatible_metrics]).to include(:total_sales, :average_order_value, :units_sold)
    expect(channel[:filter_ops]).to eq(%w[eq in])

    status = schema[:dimensions].find { |d| d[:name] == :payment_status }
    expect(status[:values].map { |v| v[:name] }).to include('paid', 'authorized')
    expect(status[:values].find { |v| v[:name] == 'partially_paid' }[:label]).to eq('Partially paid')
  end

  it 'describes the time range grammar and store meta' do
    expect(schema[:time_range][:presets].map { |p| p[:name] }).to include('last_month', 'yesterday', 'last_30_days')
    expect(schema[:limits]).to eq(default: 50, max: 1000)
    expect(schema[:time_range][:presets].first[:label]).to be_present
    expect(schema[:meta]).to include(:currency, :timezone, :supported_currencies)
  end

  it 'omits dimensions the caller may not reference' do
    filtered = described_class.new(store: store, allowed: ->(d) { d.subject.nil? }).to_h
    names = filtered[:dimensions].map { |d| d[:name] }
    expect(names).to include(:channel, :completed_at)
    expect(names).not_to include(:product, :customer, :category, :variant)
  end

  it 'groups members into the families that can be queried together' do
    families = schema[:families].index_by { |f| f[:name] }

    expect(families.keys).to contain_exactly(:sales, :payments, :inventory)
    expect(families[:sales][:metrics]).to include(:net_sales, :total_sales, :average_order_value)
    expect(families[:payments][:metrics]).to include(:net_payments)
    expect(families[:payments][:dimensions]).to include(:payment_method, :paid_at)
    expect(families[:inventory][:metrics]).to include(:units_received, :sell_through)
    # A sales axis never appears under another family's dimensions.
    expect(families[:inventory][:dimensions]).not_to include(:product)
  end

  it 'stamps each metric with its family, resolving derived ones through their components' do
    by_name = schema[:metrics].index_by { |m| m[:name] }

    expect(by_name[:net_sales][:family]).to eq(:sales)
    expect(by_name[:average_order_value][:family]).to eq(:sales)
    expect(by_name[:sell_through][:family]).to eq(:inventory)
  end
end
