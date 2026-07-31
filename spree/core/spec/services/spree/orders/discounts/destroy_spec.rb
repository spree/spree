require 'spec_helper'

module Spree
  RSpec.describe Orders::Discounts::Destroy do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }
    let!(:discount) do
      create(:discount, order: order, line_item: order.line_items.first, amount: -2, kind: 'manual').tap do
        order.recalculate_totals!
      end
    end

    describe '#call' do
      it 'destroys the row and re-sums the order totals' do
        expect do
          result = described_class.call(order: order, discount: discount)

          expect(result).to be_success
        end.to change { order.reload.total }.by(2).and change { order.discounts.count }.by(-1)
      end

      it 'refuses promotion-sourced rows' do
        discount.update_columns(kind: 'promotion')

        result = described_class.call(order: order, discount: discount)

        expect(result).to be_failure
        expect(result.error.value).to eq(:promotion_discount_not_editable)
        expect(Spree::Discount.exists?(discount.id)).to be(true)
      end
    end
  end
end
