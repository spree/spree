require 'spec_helper'

module Spree
  RSpec.describe Orders::Fees::Create do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }

    describe '#call' do
      it 'creates a surcharge fee by default and re-sums the order totals' do
        expect do
          result = described_class.call(order: order, attributes: { label: 'Gift wrap', amount: 4 })

          expect(result).to be_success
          expect(result.value).to have_attributes(label: 'Gift wrap', amount: 4, kind: 'surcharge')
        end.to change { order.reload.total }.by(4).and change { order.fee_total }.by(4)
      end

      it 'keeps an explicit kind' do
        result = described_class.call(order: order, attributes: { label: 'Handling', amount: 2, kind: 'handling' })

        expect(result.value.kind).to eq('handling')
      end

      it 'fails without touching totals when the fee is invalid' do
        expect do
          result = described_class.call(order: order, attributes: { label: 'Bad', amount: -3 })

          expect(result).to be_failure
          expect(result.value.errors[:amount]).to be_present
        end.not_to change { [order.fees.count, order.reload.total] }
      end
    end
  end
end
