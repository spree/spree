require 'spec_helper'

describe Spree::Calculator::PercentOnLineItem, type: :model do
  let(:calculator) { Spree::Calculator::PercentOnLineItem.new }
  let(:line_item) { create(:line_item) }

  before { allow(calculator).to receive_messages preferred_percent: 10 }

  describe '#compute' do
    it { expect(calculator.preferred_apply_only_on_full_priced_items).to be false }

    shared_examples 'computing amount correctly' do
      it 'rounds result correctly' do
        allow(line_item).to receive_messages amount: 31.08
        expect(calculator.compute(line_item)).to eq 3.11

        allow(line_item).to receive_messages amount: 31.00
        expect(calculator.compute(line_item)).to eq 3.10
      end

      it 'returns object.amount if computed amount is greater' do
        allow(line_item).to receive_messages amount: 30.00
        allow(calculator).to receive_messages preferred_percent: 110

        expect(calculator.compute(line_item)).to eq 30.0
      end
    end

    it_behaves_like 'computing amount correctly'

    context 'when apply_only_on_full_priced_items preference is true' do
      before { allow(calculator).to receive_messages preferred_apply_only_on_full_priced_items: true }

      context 'when line item has a compare at price' do
        before { allow(line_item).to receive_messages variant: double(compare_at_amount_in: 10) }

        it 'returns 0' do
          expect(calculator.compute(line_item)).to eq 0
        end
      end

      context 'when line item does not have a compare at price' do
        before { allow(line_item).to receive_messages amount: 31.00 }

        it_behaves_like 'computing amount correctly'
      end
    end
  end
end
