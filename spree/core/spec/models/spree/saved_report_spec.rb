require 'spec_helper'

RSpec.describe Spree::SavedReport, type: :model do
  let(:store) { @default_store }

  it 'saves a compilable query' do
    report = described_class.new(store: store, name: 'Sales by channel',
                                 query: { 'metrics' => %w[gross_revenue], 'dimensions' => %w[channel] })
    expect(report).to be_valid
    expect(report.reporting_query.metrics.map(&:name)).to eq([:gross_revenue])
  end

  it 'refuses a query the registry cannot compile' do
    report = described_class.new(store: store, name: 'Broken', query: { 'metrics' => %w[revenues] })
    expect(report).not_to be_valid
    expect(report.errors.details[:query]).to include(hash_including(error: :invalid_reporting_query))
    # The compiler's own sentence is the useful part — it names the members
    # that would have worked — so it rides along as the message.
    expect(report.errors[:query].first).to include('net_revenue')

    report = described_class.new(store: store, name: 'Broken', query: { 'metrics' => %w[gross_revenue], 'dimensions' => %w[category] })
    expect(report).not_to be_valid
    expect(report.errors[:query].first).to include('cannot be grouped')
  end

  it 'keeps names unique per store' do
    create(:saved_report, store: store, name: 'Top products', query: { 'metrics' => %w[units_sold] })
    dup = described_class.new(store: store, name: 'top products', query: { 'metrics' => %w[units_sold] })
    expect(dup).not_to be_valid
  end

  it 'keeps built-in reports read-only while allowing their deletion' do
    report = create(:saved_report, store: store, seeded: true)

    report.name = 'Renamed'
    expect(report).not_to be_valid
    expect(report.errors.details[:base]).to include(hash_including(error: :seeded_report_read_only))

    expect { report.reload.destroy! }.to change(described_class, :count).by(-1)
  end
end
