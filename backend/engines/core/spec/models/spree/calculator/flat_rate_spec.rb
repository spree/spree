require 'spec_helper'

describe Spree::Calculator::FlatRate, type: :model do
  let(:calculator) { Spree::Calculator::FlatRate.new }
  let(:line_item) { create(:line_item) }

  before { allow(line_item).to receive_messages quantity: 10 }

  describe '#compute' do
    it { expect(calculator.preferred_apply_only_on_full_priced_items).to be false }

    shared_examples 'computing amount correctly' do
      it "computes the amount as the rate when currency matches the line_item's currency" do
        calculator.preferred_amount = 25.0
        calculator.preferred_currency = 'GBP'
        allow(line_item).to receive_messages currency: 'GBP'
        expect(calculator.compute(line_item).round(2)).to eq(25.0)
      end

      it "computes the amount as 0 when currency does not match the line_item's currency" do
        calculator.preferred_amount = 100.0
        calculator.preferred_currency = 'GBP'
        allow(line_item).to receive_messages currency: 'USD'
        expect(calculator.compute(line_item).round(2)).to eq(0.0)
      end

      it 'computes the amount as 0 when currency is blank' do
        calculator.preferred_amount = 100.0
        calculator.preferred_currency = ''
        allow(line_item).to receive_messages currency: 'GBP'
        expect(calculator.compute(line_item).round(2)).to eq(0.0)
      end

      it 'computes the amount as the rate when the currencies use different casing' do
        calculator.preferred_amount = 100.0
        calculator.preferred_currency = 'gBp'
        allow(line_item).to receive_messages currency: 'GBP'
        expect(calculator.compute(line_item).round(2)).to eq(100.0)
      end

      it 'computes the amount as 0 when there is no object' do
        calculator.preferred_amount = 100.0
        calculator.preferred_currency = 'GBP'
        expect(calculator.compute.round(2)).to eq(0.0)
      end
    end

    it_behaves_like 'computing amount correctly'

    context 'when apply_only_on_full_priced_items is true' do
      before { calculator.preferred_apply_only_on_full_priced_items = true }

      context 'when line item has compare at price' do
        before { allow(line_item).to receive_messages variant: double(compare_at_amount_in: 10) }

        it 'returns 0' do
          expect(calculator.compute(line_item)).to eq(0.0)
        end
      end

      context 'when line item does not have compare at price' do
        it_behaves_like 'computing amount correctly'
      end
    end
  end
end
