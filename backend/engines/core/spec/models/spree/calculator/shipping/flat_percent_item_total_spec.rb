require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatPercentItemTotal, type: :model do
      subject { FlatPercentItemTotal.new(preferred_flat_percent: 10) }

      let(:variant1) { build(:variant, price: 10.11) }
      let(:variant2) { build(:variant, price: 20.2222) }

      let(:inventory_unit1) { build(:inventory_unit, quantity: 2, variant: variant1, line_item: line_item1) }
      let(:inventory_unit2) { build(:inventory_unit, quantity: 1, variant: variant2, line_item: line_item2) }
      let(:inventory_units) { [inventory_unit1, inventory_unit2] }

      let(:line_item1) { build(:line_item, variant: variant1, price: variant1.price) }
      let(:line_item2) { build(:line_item, variant: variant2, price: variant2.price) }

      let(:package) do
        build(:stock_package, contents: inventory_units.map { |iu| ::Spree::Stock::ContentItem.new(iu) })
      end

      it 'rounds result correctly' do
        expect(subject.compute(package)).to eq(4.04)
      end
    end
  end
end
