require 'spec_helper'

describe Spree::Calculator::FlexiRate, type: :model do
  let(:calculator) { Spree::Calculator::FlexiRate.new }

  let(:order) do
    mock_model(
      Spree::Order, quantity: 10
    )
  end

  context 'compute' do
    it 'computes amount correctly when all fees are 0' do
      expect(calculator.compute(order).round(2)).to eq(0.0)
    end

    it 'computes amount correctly when first_item has a value' do
      allow(calculator).to receive_messages preferred_first_item: 1.0
      expect(calculator.compute(order).round(2)).to eq(1.0)
    end

    it 'computes amount correctly when additional_items has a value' do
      allow(calculator).to receive_messages preferred_additional_item: 1.0
      expect(calculator.compute(order).round(2)).to eq(9.0)
    end

    it 'computes amount correctly when additional_items and first_item have values' do
      allow(calculator).to receive_messages preferred_first_item: 5.0, preferred_additional_item: 1.0
      expect(calculator.compute(order).round(2)).to eq(14.0)
    end

    it 'computes amount correctly when additional_items and first_item have values AND max items has value' do
      allow(calculator).to receive_messages preferred_first_item: 5.0, preferred_additional_item: 1.0, preferred_max_items: 3
      expect(calculator.compute(order).round(2)).to eq(7.0)
    end

    it 'allows creation of new object with all the attributes' do
      Spree::Calculator::FlexiRate.new(preferred_first_item: 1, preferred_additional_item: 1, preferred_max_items: 1)
    end
  end
end
