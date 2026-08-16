require 'spec_helper'

RSpec.describe Spree::CommissionLine, type: :model do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:vendor) { create(:vendor, :approved, store: store) }
  let(:line_item) { create(:line_item, order: order) }
  let(:fulfillment) { create(:fulfillment, order: order) }

  describe 'what it is charged against' do
    it 'accepts an item' do
      expect(build(:commission_line, order: order, vendor: vendor, line_item: line_item)).to be_valid
    end

    it 'accepts a delivery' do
      expect(
        build(:commission_line, order: order, vendor: vendor, line_item: nil, fulfillment: fulfillment)
      ).to be_valid
    end

    it 'refuses both at once' do
      expect(
        build(:commission_line, order: order, vendor: vendor, line_item: line_item, fulfillment: fulfillment)
      ).not_to be_valid
    end

    it 'refuses neither' do
      expect(build(:commission_line, order: order, vendor: vendor, line_item: nil)).not_to be_valid
    end
  end

  # A settlement record has to survive the configuration that produced it,
  # because a marketplace still has to explain a charge it already made.
  it 'outlives the rate it was calculated from' do
    rate = create(:commission_rate, store: store)
    line = create(:commission_line, order: order, vendor: vendor, line_item: line_item, commission_rate: rate)

    rate.destroy

    expect(line.reload).to be_persisted
    expect(line.commission_rate).to be_nil
    expect(line.rate).to eq(10)
  end

  it 'renders its parts as money' do
    line = build(:commission_line, amount: 10, tax_amount: 2.1, total: 12.1, currency: 'USD')

    expect(line.display_amount.to_s).to eq('$10.00')
    expect(line.display_tax_amount.to_s).to eq('$2.10')
    expect(line.display_total.to_s).to eq('$12.10')
  end
end
