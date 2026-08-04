require 'spec_helper'

module Spree
  RSpec.describe Orders::Discounts::Create do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store, line_items_count: 2, line_items_price: 10) }
    let(:line_item) { order.line_items.first }

    describe '#call' do
      context 'targeting a line item' do
        it 'creates a flat manual discount row and re-sums the order totals' do
          expect do
            result = described_class.call(order: order, label: 'Appeasement', value: 3, line_item: line_item)

            expect(result).to be_success
            expect(result.value.sole).to have_attributes(
              line_item: line_item, label: 'Appeasement', amount: -3, kind: 'manual',
              value: 3, value_type: 'flat'
            )
          end.to change { order.reload.total }.by(-3).and change { order.adjustment_total }.by(-3)
        end

        it 'computes a percent discount from the line item amount' do
          result = described_class.call(order: order, label: 'Ten off', value: 10, value_type: 'percent', line_item: line_item)

          expect(result.value.sole.amount).to eq(-1)
        end

        it 'clamps the amount so the line item never goes below zero' do
          create(:discount, order: order, line_item: line_item, amount: -8, kind: 'manual')

          result = described_class.call(order: order, label: 'Big', value: 50, line_item: line_item)

          expect(result.value.sole.amount).to eq(-2)
        end

        it 'fails without creating a row when the line item is already fully discounted' do
          create(:discount, order: order, line_item: line_item, amount: -10, kind: 'manual')

          expect do
            result = described_class.call(order: order, label: 'Nothing left', value: 5, line_item: line_item)

            expect(result).to be_failure
            expect(result.error.to_s).to eq(Spree.t('errors.messages.discount_has_no_effect'))
          end.not_to change { order.discounts.count }
        end
      end

      context 'order-level (no line item)' do
        it 'distributes the amount across line items proportionally to their discountable bases' do
          expect do
            result = described_class.call(order: order, label: 'Order-wide', value: 10)

            expect(result).to be_success
            expect(result.value.map(&:line_item)).to match_array(order.line_items)
            expect(result.value.sum(&:amount)).to eq(-10)
          end.to change { order.reload.total }.by(-10)
        end

        it 'caps the distributed amount at the sum of the discountable bases' do
          result = described_class.call(order: order, label: 'Everything', value: 999)

          expect(result.value.sum(&:amount)).to eq(-20)
          expect(order.reload.total).to eq(order.delivery_total + order.additional_tax_total)
        end

        it 'skips line items with no remaining discountable base' do
          create(:discount, order: order, line_item: line_item, amount: -10, kind: 'manual')

          result = described_class.call(order: order, label: 'Rest', value: 4)

          expect(result.value.sole.line_item).to eq(order.line_items.second)
        end
      end

      context 'with invalid input' do
        it 'fails on a non-positive value' do
          result = described_class.call(order: order, label: 'Zero', value: 0)

          expect(result).to be_failure
          expect(result.error.to_s).to eq(Spree.t('errors.messages.discount_value_must_be_positive'))
        end

        it 'fails on an unknown value_type' do
          result = described_class.call(order: order, label: 'Odd', value: 5, value_type: 'points')

          expect(result).to be_failure
          expect(result.error.to_s).to eq(Spree.t('errors.messages.discount_value_type_invalid'))
        end
      end
    end
  end
end
