require 'spec_helper'

describe Spree::Discount, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  it 'is valid with an order owner and a line item adjustable' do
    discount = described_class.new(order: order, line_item: line_item, amount: -2, label: 'Promo', kind: 'manual')
    expect(discount).to be_valid
  end

  it 'requires exactly one owner' do
    discount = described_class.new(line_item: line_item, amount: -2, label: 'Promo', kind: 'manual')
    expect(discount).not_to be_valid
    expect(discount.errors[:base]).to include(Spree.t('errors.messages.exactly_one_of_cart_or_order'))
  end

  it 'requires exactly one adjustable' do
    discount = described_class.new(order: order, amount: -2, label: 'Promo', kind: 'manual')
    expect(discount).not_to be_valid
    expect(discount.errors[:base]).to include(Spree.t('errors.messages.exactly_one_adjustable'))

    discount.line_item = line_item
    discount.fulfillment = create(:fulfillment, order: order)
    expect(discount).not_to be_valid
  end

  it 'rejects positive amounts' do
    discount = described_class.new(order: order, line_item: line_item, amount: 2, label: 'Promo', kind: 'manual')
    expect(discount).not_to be_valid
    expect(discount.errors[:amount]).to be_present
  end

  it 'keeps provenance snapshots when the promotion is gone' do
    discount = create(:discount, order: order, line_item: line_item, amount: -2, kind: 'promotion',
                      code: 'SUMMER10', value: 10, value_type: 'percent')
    expect(discount.reload.code).to eq('SUMMER10')
    expect(discount.promotion).to be_nil
  end

  describe 'scopes' do
    let!(:line_discount) { create(:discount, order: order, line_item: line_item, kind: 'promotion') }
    let!(:manual_discount) { create(:discount, order: order, line_item: line_item, kind: 'manual') }

    it 'filters by kind and adjustable' do
      expect(described_class.promotion).to contain_exactly(line_discount)
      expect(described_class.manual).to contain_exactly(manual_discount)
      expect(described_class.for_line_items).to contain_exactly(line_discount, manual_discount)
      expect(described_class.for_fulfillments).to be_empty
    end
  end

  describe '#owner' do
    it 'returns the order' do
      discount = build(:discount, order: order, line_item: line_item)
      expect(discount.owner).to eq(order)
    end
  end
end
