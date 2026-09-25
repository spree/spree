require 'spec_helper'

module Spree
  RSpec.describe Orders::Fees::Update do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }
    let!(:fee) do
      create(:fee, order: order, amount: 4, kind: 'surcharge').tap { order.recalculate_totals! }
    end

    describe '#call' do
      it 'updates the row and re-sums the order totals' do
        expect do
          result = described_class.call(order: order, fee: fee, attributes: { amount: 6, label: 'Rush' })

          expect(result).to be_success
          expect(fee.reload).to have_attributes(amount: 6, label: 'Rush')
        end.to change { order.reload.total }.by(2)
      end

      it 'fails without touching totals when the update is invalid' do
        expect do
          result = described_class.call(order: order, fee: fee, attributes: { amount: -1 })

          expect(result).to be_failure
        end.not_to change { order.reload.total }
      end

      context 'when the order has been paid in full' do
        before do
          create(:payment, amount: order.total, order: order, status: 'completed')
          order.update_statuses!
        end

        it 'reads partially paid once the fee raises the total' do
          expect do
            described_class.call(order: order, fee: fee, attributes: { amount: 6 })
          end.to change { order.reload.payment_status }.from('paid').to('partially_paid')
        end
      end
    end
  end
end
