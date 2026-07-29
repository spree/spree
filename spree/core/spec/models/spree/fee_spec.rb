require 'spec_helper'

describe Spree::Fee, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  it 'is valid order-level (no adjustable)' do
    fee = described_class.new(order: order, amount: 5, label: 'COD', kind: 'payment')
    expect(fee).to be_valid
    expect(fee).to be_order_level
  end

  it 'may target a line item' do
    fee = described_class.new(order: order, line_item: order.line_items.first, amount: 3, label: 'Gift wrap', kind: 'gift_wrap')
    expect(fee).to be_valid
    expect(fee).not_to be_order_level
  end

  it 'rejects negative amounts — credits are manual discounts' do
    fee = described_class.new(order: order, amount: -5, label: 'Credit', kind: 'surcharge')
    expect(fee).not_to be_valid
    expect(fee.errors[:amount]).to be_present
  end

  it 'requires kind and label' do
    fee = described_class.new(order: order, amount: 5)
    expect(fee).not_to be_valid
    expect(fee.errors[:kind]).to be_present
    expect(fee.errors[:label]).to be_present
  end

  it 'destroys its tax lines with it' do
    fee = create(:fee, order: order)
    create(:tax_line, order: order, fee: fee, line_item: nil)
    expect { fee.destroy! }.to change(Spree::TaxLine, :count).by(-1)
  end
end
