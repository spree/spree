require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe PriceSack do
      subject(:calculator) do
        calculator = PriceSack.new
        calculator.preferred_minimal_amount = 5
        calculator.preferred_normal_amount = 10
        calculator.preferred_discount_amount = 1
        calculator
      end

      let(:line_item) { build(:line_item, variant: variant, price: variant.price) }
      let(:variant) { build(:variant, price: 2) }

      let(:inventory_unit1) {  }

      let(:normal_package) do
        iu = build(:inventory_unit, quantity: 2, variant: variant, line_item: line_item)
        build(:stock_package, contents: [::Spree::Stock::ContentItem.new(iu)])
      end

      let(:discount_package) do
        iu = build(:inventory_unit, quantity: 4, variant: variant, line_item: line_item)
        build(:stock_package, contents: [::Spree::Stock::ContentItem.new(iu)])
      end

      it 'computes the correct amount' do
        expect(calculator.compute(normal_package)).to eq(calculator.preferred_normal_amount)
        expect(calculator.compute(discount_package)).to eq(calculator.preferred_discount_amount)
      end
    end
  end
end
