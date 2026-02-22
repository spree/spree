require 'spec_helper'

RSpec.describe Spree::ReportLineItem do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:report) { create(:report, store: store, currency: 'USD') }
  let(:report_line_item) { described_class.new(report: report, record: order) }

  describe '.headers' do
    it 'returns array of hashes with name and label' do
      allow(described_class).to receive(:attribute_types).and_return({ 'foo' => nil })
      allow(Spree).to receive(:t).with(:foo).and_return('Foo Label')

      expect(described_class.headers).to eq([{name: :foo, label: 'Foo Label'}])
    end
  end

  describe '.csv_headers' do
    it 'returns array of attribute keys' do
      allow(described_class).to receive(:attribute_types).and_return({ 'foo' => nil, 'bar' => nil })
      expect(described_class.csv_headers).to eq(['foo', 'bar'])
    end
  end

  describe '#to_csv' do
    it 'returns array of attribute values' do
      allow(described_class).to receive(:attribute_types).and_return({ 'foo' => nil, 'bar' => nil })
      report_line_item = described_class.new
      allow(report_line_item).to receive(:foo).and_return('foo_value')
      allow(report_line_item).to receive(:bar).and_return('bar_value')

      expect(report_line_item.to_csv).to eq(['foo_value', 'bar_value'])
    end
  end
end
