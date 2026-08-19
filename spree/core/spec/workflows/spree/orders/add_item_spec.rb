require 'spec_helper'

module Spree
  describe Orders::AddItem do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals, line_items_count: 1, line_items_price: 10) }
    let(:variant) { create(:variant, price: 20) }

    describe '#call' do
      it 'adds a line item to the placed order and re-sums its totals' do
        expect do
          result = subject.call(order: order, variant: variant, quantity: 2)

          expect(result).to be_success
          expect(result.value).to have_attributes(variant: variant, quantity: 2)
        end.to change { order.line_items.count }.by(1)

        expect(order.reload.item_total).to eq(10 + 40)
      end

      it 'increments an existing line item instead of adding a new one' do
        subject.call(order: order, variant: variant, quantity: 1)

        expect do
          result = subject.call(order: order, variant: variant, quantity: 2)

          expect(result).to be_success
        end.not_to change { order.line_items.count }

        expect(order.line_items.find_by(variant: variant).quantity).to eq(3)
      end

      it 'fails when the variant has insufficient stock' do
        variant.stock_levels.first.update!(backorderable: false)

        result = subject.call(order: order, variant: variant, quantity: 10)

        expect(result).to be_failure
        expect(order.reload.line_items.map(&:variant)).not_to include(variant)
      end

      it 'does not run a stock reservation pass on a placed order' do
        expect do
          subject.call(order: order, variant: variant, quantity: 1)
        end.not_to change { Spree::StockReservation.count }
      end
    end
  end
end
