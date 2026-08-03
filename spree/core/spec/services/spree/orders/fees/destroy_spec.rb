require 'spec_helper'

module Spree
  RSpec.describe Orders::Fees::Destroy do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }
    let!(:fee) do
      create(:fee, order: order, amount: 4, kind: 'surcharge').tap { order.recalculate_totals! }
    end

    describe '#call' do
      it 'destroys the row and re-sums the order totals' do
        expect do
          result = described_class.call(order: order, fee: fee)

          expect(result).to be_success
        end.to change { order.reload.total }.by(-4).and change { order.fees.count }.by(-1)
      end
    end
  end
end
