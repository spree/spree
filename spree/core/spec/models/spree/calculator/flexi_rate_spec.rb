require 'spec_helper'

describe Spree::Calculator::FlexiRate, type: :model do
  let(:calculator) { Spree::Calculator::FlexiRate.new }
  let(:line_item) { create(:line_item) }

  before { allow(line_item).to receive_messages quantity: 10 }

  describe '#compute' do
    it { expect(calculator.preferred_apply_only_on_full_priced_items).to be false }

    shared_examples 'computes amount correctly' do
      it 'computes amount correctly when all fees are 0' do
        expect(calculator.compute(line_item).round(2)).to eq(0.0)
      end

      it 'computes amount correctly when first_item has a value' do
        allow(calculator).to receive_messages preferred_first_item: 1.0
        expect(calculator.compute(line_item).round(2)).to eq(1.0)
      end

      it 'computes amount correctly when additional_items has a value' do
        allow(calculator).to receive_messages preferred_additional_item: 1.0
        expect(calculator.compute(line_item).round(2)).to eq(9.0)
      end

      it 'computes amount correctly when additional_items and first_item have values' do
        allow(calculator).to receive_messages preferred_first_item: 5.0, preferred_additional_item: 1.0
        expect(calculator.compute(line_item).round(2)).to eq(14.0)
      end

      it 'computes amount correctly when additional_items and first_item have values AND max items has value' do
        allow(calculator).to receive_messages preferred_first_item: 5.0, preferred_additional_item: 1.0, preferred_max_items: 3
        expect(calculator.compute(line_item).round(2)).to eq(7.0)
      end

      it 'allows creation of new object with all the attributes' do
        Spree::Calculator::FlexiRate.new(preferred_first_item: 1, preferred_additional_item: 1, preferred_max_items: 1)
      end
    end

    context 'when apply_only_on_full_priced_items is true' do
      before { allow(calculator).to receive_messages preferred_apply_only_on_full_priced_items: true }

      it 'returns 0' do
        allow(line_item).to receive_messages variant: double('Variant', compare_at_amount_in: 1.0)
        expect(calculator.compute(line_item)).to eq(0.0)
      end

      it_behaves_like 'computes amount correctly'
    end
  end
end
