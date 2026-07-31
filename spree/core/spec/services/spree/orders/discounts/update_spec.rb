require 'spec_helper'

module Spree
  RSpec.describe Orders::Discounts::Update do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:discount) { create(:discount, order: order, line_item: order.line_items.first, amount: -2, kind: 'manual') }

    describe '#call' do
      it 'updates the row and re-sums the order totals' do
        expect do
          result = described_class.call(order: order, discount: discount, attributes: { amount: -5, label: 'Bigger' })

          expect(result).to be_success
          expect(discount.reload).to have_attributes(amount: -5, label: 'Bigger')
        end.to change { order.reload.total }.by(-5)
      end

      it 'refuses promotion-sourced rows' do
        discount.update_columns(kind: 'promotion')

        result = described_class.call(order: order, discount: discount, attributes: { label: 'Nope' })

        expect(result).to be_failure
        expect(result.error.value).to eq(:promotion_discount_not_editable)
      end

      it 'fails without touching totals when the update is invalid' do
        expect do
          result = described_class.call(order: order, discount: discount, attributes: { amount: 3 })

          expect(result).to be_failure
        end.not_to change { order.reload.total }
      end
    end
  end
end
