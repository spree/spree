require 'spec_helper'

RSpec.describe Spree::Calculator::Shipping::FlatRate, type: :model do
  let(:variant1) { build(:variant, price: 10, weight: 0.75) }
  let(:variant2) { build(:variant, price: 15, weight: 2.5) }

  let(:line_item1) { build(:line_item, variant: variant1, price: 10) }
  let(:line_item2) { build(:line_item, variant: variant2, price: 15) }

  let(:inventory_unit1) { build(:inventory_unit, quantity: 2, variant: variant1, line_item: line_item1) }
  let(:inventory_unit2) { build(:inventory_unit, quantity: 1, variant: variant2, line_item: line_item2) }
  let(:inventory_units) { [inventory_unit1, inventory_unit2] }

  let(:package) { build(:stock_package, contents: inventory_units.map { |iu| ::Spree::Stock::ContentItem.new(iu) }) }

  context 'without any constraints' do
    let(:calculator) { described_class.new(preferred_amount: 5) }

    it 'returns the amount' do
      expect(calculator.compute(package)).to eq(5)
    end
  end

  context 'with weight constraints' do
    let(:calculator_1) { described_class.new(preferred_amount: 5, preferred_minimum_weight: 2, preferred_maximum_weight: 4) }
    let(:calculator_2) { described_class.new(preferred_amount: 5, preferred_minimum_weight: 4, preferred_maximum_weight: 8) }

    let(:calculator_3) { described_class.new(preferred_amount: 5, preferred_minimum_weight: nil, preferred_maximum_weight: 4) }
    let(:calculator_4) { described_class.new(preferred_amount: 5, preferred_minimum_weight: nil, preferred_maximum_weight: 3) }

    let(:calculator_5) { described_class.new(preferred_amount: 5, preferred_minimum_weight: 3, preferred_maximum_weight: nil) }
    let(:calculator_6) { described_class.new(preferred_amount: 5, preferred_minimum_weight: 4, preferred_maximum_weight: nil) }
    let(:calculator_7) { described_class.new(preferred_amount: 5, preferred_minimum_weight: 5, preferred_maximum_weight: nil) }

    it 'returns amount based on the contents item total' do
      expect(calculator_1.compute(package)).to eq(5.00)
      expect(calculator_2.compute(package)).to be_nil

      expect(calculator_3.compute(package)).to eq(5.00)
      expect(calculator_4.compute(package)).to be_nil

      expect(calculator_5.compute(package)).to eq(5.00)
      expect(calculator_6.compute(package)).to be_nil
      expect(calculator_7.compute(package)).to be_nil
    end
  end

  context 'with price constraints' do
    let(:calculator_1) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: 20, preferred_maximum_item_total: 35) }
    let(:calculator_2) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: 35, preferred_maximum_item_total: 80) }

    let(:calculator_3) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: nil, preferred_maximum_item_total: 35) }
    let(:calculator_4) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: nil, preferred_maximum_item_total: 34) }

    let(:calculator_5) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: 34, preferred_maximum_item_total: nil) }
    let(:calculator_6) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: 35, preferred_maximum_item_total: nil) }
    let(:calculator_7) { described_class.new(preferred_amount: 5, preferred_minimum_item_total: 36, preferred_maximum_item_total: nil) }

    it 'returns amount based on the contents weight' do
      expect(calculator_1.compute(package)).to eq(5.00)
      expect(calculator_2.compute(package)).to be_nil

      expect(calculator_3.compute(package)).to eq(5.00)
      expect(calculator_4.compute(package)).to be_nil

      expect(calculator_5.compute(package)).to eq(5.00)
      expect(calculator_6.compute(package)).to be_nil
      expect(calculator_7.compute(package)).to be_nil
    end
  end

  context 'with both weight and price constraints' do
    let(:calculator_1) do
      described_class.new(
        preferred_amount: 5,
        preferred_minimum_item_total: 20, preferred_maximum_item_total: 35,
        preferred_minimum_weight: 2, preferred_maximum_weight: 4
      )
    end

    let(:calculator_2) do
      described_class.new(
        preferred_amount: 5,
        preferred_minimum_item_total: 35, preferred_maximum_item_total: 80,
        preferred_minimum_weight: 2, preferred_maximum_weight: 4
      )
    end

    let(:calculator_3) do
      described_class.new(
        preferred_amount: 5,
        preferred_minimum_item_total: 20, preferred_maximum_item_total: 35,
        preferred_minimum_weight: 4, preferred_maximum_weight: 8
      )
    end

    it 'returns amount based on the contents weight and price' do
      expect(calculator_1.compute(package)).to eq(5.00)
      expect(calculator_2.compute(package)).to be_nil
      expect(calculator_3.compute(package)).to be_nil
    end
  end
end
