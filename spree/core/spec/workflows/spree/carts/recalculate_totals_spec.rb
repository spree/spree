require 'spec_helper'

module Spree
  RSpec.describe Carts::RecalculateTotals do
    let(:store) { @default_store }

    describe 'live records' do
      let(:order) { create(:order_with_line_items, store: store, line_items_count: 2, line_items_price: 10) }

      it 'recomputes item count and money totals from the rows and persists them' do
        order.update_columns(item_total: 0, total_quantity: 0, total: 0)

        result = described_class.call(cart: order)

        expect(result).to be_success
        order.reload
        expect(order.total_quantity).to eq(2)
        expect(order.item_total).to eq(20)
        expect(order.total).to eq(order.item_total + order.delivery_total + order.adjustment_total)
      end

      it 'nets refunds out of the payment total' do
        order = create(:completed_order_with_totals, store: store)
        payment = create(:payment, order: order, amount: order.total, state: 'completed')
        create(:refund, payment: payment, amount: 5)

        described_class.call(cart: order)

        expect(order.reload.payment_total).to eq(payment.amount - 5)
      end
    end

    describe 'the completed-order money freeze' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'never regenerates typed rows but re-sums them (the post-placement resum path)' do
        # The order's own provider, not the global default — selection is
        # per-market since 6.0, so stubbing the global would assert nothing.
        provider = instance_double(Spree::TaxProvider::Internal)
        allow(order).to receive(:tax_provider).and_return(provider)
        expect(provider).not_to receive(:estimate)

        line_item = order.line_items.first
        order.discounts.create!(line_item: line_item, label: 'Manual', amount: -3,
                                kind: 'manual', value: 3, value_type: 'flat')

        expect { described_class.call(cart: order) }
          .to change { order.reload.discount_total }.by(0).and change { order.reload.adjustment_total }.by(-3)
      end
    end

    describe 'carts' do
      let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 1, line_items_price: 15) }

      it 'recomputes cart totals through the same flow' do
        cart.update_columns(item_total: 0, total: 0, total_quantity: 0)

        described_class.call(cart: cart)

        cart.reload
        expect(cart.item_total).to eq(15)
        expect(cart.total_quantity).to eq(1)
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
      end
    end
  end
end
