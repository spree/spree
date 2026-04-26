require 'spec_helper'

RSpec.describe Spree::LineItems::FindByVariant do
  subject { described_class.new }

  let(:order) { create(:order) }
  let(:variant) { create(:variant) }

  context 'when no matching line item exists' do
    it 'returns nil' do
      result = subject.execute(order: order, variant: variant)
      expect(result).to be_nil
    end
  end

  context 'when a matching line item exists' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    context 'when comparator returns true' do
      it 'returns the line item' do
        result = subject.execute(order: order, variant: variant)
        expect(result).to eq(line_item)
      end
    end

    context 'when comparator returns false' do
      before do
        comparator = double('comparator')
        allow(comparator).to receive(:call).and_return(double(value: false))
        allow(Spree).to receive(:cart_compare_line_items_service).and_return(comparator)
      end

      it 'returns nil' do
        result = subject.execute(order: order, variant: variant)
        expect(result).to be_nil
      end
    end

    context 'with loaded line items association' do
      before { order.line_items.load }

      it 'returns the line item when comparator returns true' do
        result = subject.execute(order: order, variant: variant)
        expect(result).to eq(line_item)
      end

      context 'when comparator returns false' do
        before do
          comparator = double('comparator')
          allow(comparator).to receive(:call).and_return(double(value: false))
          allow(Spree).to receive(:cart_compare_line_items_service).and_return(comparator)
        end

        it 'returns nil' do
          result = subject.execute(order: order, variant: variant)
          expect(result).to be_nil
        end
      end
    end
  end
end
