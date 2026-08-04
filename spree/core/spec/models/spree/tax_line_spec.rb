require 'spec_helper'

describe Spree::TaxLine, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  it 'is valid on a line item' do
    tax_line = described_class.new(order: order, line_item: line_item, amount: 1, rate: 0.1, label: 'VAT')
    expect(tax_line).to be_valid
  end

  it 'accepts a fee as adjustable' do
    fee = create(:fee, order: order)
    tax_line = described_class.new(order: order, fee: fee, amount: 0.4, rate: 0.2, label: 'VAT')
    expect(tax_line).to be_valid
    expect(tax_line.adjustable).to eq(fee)
  end

  it 'requires exactly one adjustable' do
    tax_line = described_class.new(order: order, amount: 1, rate: 0.1, label: 'VAT')
    expect(tax_line).not_to be_valid

    tax_line.line_item = line_item
    tax_line.fulfillment = create(:fulfillment, order: order)
    expect(tax_line).not_to be_valid
  end

  it 'stays meaningful without a tax rate' do
    tax_line = create(:tax_line, order: order, line_item: line_item, tax_rate: nil, provider_id: 'avalara', rate: 0.0825)
    expect(tax_line.reload.rate).to eq(0.0825)
    expect(tax_line.tax_rate).to be_nil
  end

  describe 'included vs additional' do
    let!(:included_line) { create(:tax_line, order: order, line_item: line_item, included: true) }
    let!(:additional_line) { create(:tax_line, order: order, line_item: line_item, included: false) }

    it 'partitions by the included flag' do
      expect(described_class.included_in_price).to contain_exactly(included_line)
      expect(described_class.additional).to contain_exactly(additional_line)
      expect(included_line).to be_included
      expect(additional_line).to be_additional
    end
  end
end
