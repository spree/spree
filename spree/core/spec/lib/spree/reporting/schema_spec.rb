require 'spec_helper'

RSpec.describe Spree::Reporting::Schema do
  let(:store) { @default_store }

  subject(:schema) { described_class.new(store: store).to_h }

  it 'describes metrics with localized labels, formats and currency' do
    metric = schema[:metrics].find { |m| m[:name] == :gross_revenue }
    expect(metric[:label]).to eq('Total sales')
    expect(metric[:description]).to be_present
    expect(metric[:format]).to eq(:money)
    expect(metric[:currency]).to eq(store.default_currency)
  end

  it 'publishes compatible metrics, filter ops and enumerated values per dimension' do
    category = schema[:dimensions].find { |d| d[:name] == :category }
    expect(category[:compatible_metrics]).to include(:net_revenue, :units_sold)
    expect(category[:compatible_metrics]).not_to include(:gross_revenue, :aov)

    channel = schema[:dimensions].find { |d| d[:name] == :channel }
    expect(channel[:compatible_metrics]).to include(:gross_revenue, :aov, :units_sold)
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
end
