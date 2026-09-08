require 'spec_helper'

RSpec.shared_examples 'a line item lookup host' do
  let(:record) { new_record_with_line_items }
  let(:line_item) { record.line_items.first }
  let(:absent_variant) { create(:variant) }

  describe '#find_line_item_by_variant' do
    it 'finds the line item selling the variant' do
      expect(record.find_line_item_by_variant(line_item.variant)).to eq(line_item)
    end

    it 'answers nil for a variant that is not on the record' do
      expect(record.find_line_item_by_variant(absent_variant)).to be_nil
    end
  end

  describe '#quantity_of' do
    it 'returns the units already on the record' do
      line_item.update_column(:quantity, 3)

      expect(record.quantity_of(line_item.variant)).to eq(3)
    end

    it 'returns zero for a variant that is not on the record' do
      expect(record.quantity_of(absent_variant)).to eq(0)
    end
  end
end

RSpec.describe Spree::Purchase::LineItemLookup do
  context 'included in Spree::Cart' do
    def new_record_with_line_items
      create(:cart_with_line_items, store: @default_store)
    end

    it_behaves_like 'a line item lookup host'
  end

  context 'included in Spree::Order' do
    def new_record_with_line_items
      create(:order_with_line_items, store: @default_store)
    end

    it_behaves_like 'a line item lookup host'
  end
end
