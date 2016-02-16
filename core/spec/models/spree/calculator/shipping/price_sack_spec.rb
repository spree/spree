require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe PriceSack do
      let(:variant) { build(:variant, price: 2) }
      subject(:calculator) do
        calculator = PriceSack.new
        calculator.preferred_minimal_amount = 5
        calculator.preferred_normal_amount = 10
        calculator.preferred_discount_amount = 1
        calculator
      end

      let(:normal_package) do
        build(:stock_package, variants_contents: { variant => 2 })
      end

      let(:discount_package) do
        build(:stock_package, variants_contents: { variant => 4 })
      end

      it 'computes the correct amount' do
        expect(calculator.compute(normal_package)).to eq(calculator.preferred_normal_amount)
        expect(calculator.compute(discount_package)).to eq(calculator.preferred_discount_amount)
      end
    end
  end
end
