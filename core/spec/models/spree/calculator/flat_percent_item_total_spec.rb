require 'spec_helper'

module Spree
  class Calculator
    describe FlatPercentItemTotal do
      subject(:calculator) do 
        FlatPercentItemTotal.new(preferred_flat_percent: 10, calculable: calculable)
      end
      let(:order) { mock_model Order }
      let(:calculable) { mock_model Promotion::Actions::CreateAdjustment, promotion_id: 1 }

      context "#compute" do
        it "should round result correctly" do
          allow(order).to receive_messages amount: 31.08
          expect(calculator.compute(order)).to eq 3.11

          allow(order).to receive_messages amount: 31.00
          expect(calculator.compute(order)).to eq 3.10
        end

        it 'returns object.amount if computed amount is greater' do
          allow(calculator).to receive_messages preferred_flat_percent: 110
          allow(order).to receive_messages amount: 30.00

          expect(calculator.compute(order)).to eq 30.0
        end

        context 'with accumulator' do
          let(:accumulator) { double(item_total_with_promotion: 30.00) }
          before { allow(order).to receive(:promotion_accumulator).and_return(accumulator) }

          it 'should calculate as a percentage of accumulated item total' do
            expect(calculator.compute(order)).to eq(3)
          end
        end
      end
    end
  end
end
