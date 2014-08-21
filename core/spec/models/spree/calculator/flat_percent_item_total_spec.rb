require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new }
  let(:line_item) { mock_model Spree::LineItem }

  before { calculator.stub preferred_flat_percent: 10 }

  context "compute" do
    it "should round result correctly" do
      line_item.stub amount: 31.08
      expect(calculator.compute(line_item)).to eq 3.11

      line_item.stub amount: 31.00
      expect(calculator.compute(line_item)).to eq 3.10
    end

    it 'returns object.amount if computed amount is greater' do
      calculator.stub preferred_flat_percent: 110
      line_item.stub amount: 30.00

      expect(calculator.compute(line_item)).to eq 30.0
    end
  end
end
