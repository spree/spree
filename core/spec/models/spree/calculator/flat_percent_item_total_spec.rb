require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal, :type => :model do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10, calculable: calculable) }
  let(:order) { mock_model Spree::Order }
  let(:calculable) { mock_model Spree::Promotion::Actions::CreateAdjustment, promotion_id: 1}
  let(:accumulator) { double(item_total_with_promotion: 31.08) }

  before { allow(order).to receive(:promotion_accumulator).and_return(accumulator) }

  context "compute" do

    it "should calculate percentage and round result correctly" do 
      expect(calculator.compute(order)).to eq(3.11)
    end

    context 'with percentage more than 100' do
      before { calculator.preferred_flat_percent = 110 }

      it 'should return item_total_with_promotion' do
        expect(calculator.compute(order)).to eq(31.08)
      end
    end

  end
end
