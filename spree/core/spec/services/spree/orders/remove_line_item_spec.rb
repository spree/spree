require 'spec_helper'

module Spree
  describe Orders::RemoveLineItem do
    let(:order) { create(:order_with_line_items, store: @default_store) }
    let(:line_item) { order.line_items.first }

    it 'removes the line item from the order' do
      expect {
        described_class.call(order: order, line_item: line_item)
      }.to change { order.reload.line_items.count }.by(-1)
    end

    # Draft-order edits apply whole or fail; only carts get the cart
    # workflow's warn-and-skip contract, so this must not route there.
    it 'uses the order workflow, not the cart one' do
      expect(Spree::Orders::UpsertItems).to receive(:new).and_call_original
      expect(Spree::Carts::UpsertItems).not_to receive(:new)

      described_class.call(order: order, line_item: line_item)
    end

    it 'fails outright when a handler vetoes the removal' do
      Spree.hooks.register('orders.upsert_items.validate') { |flow| flow.reject!('locked') }

      result = nil
      expect {
        result = described_class.call(order: order, line_item: line_item)
      }.not_to change { [order.reload.line_items.count, order.total] }

      expect(result).to be_failure
      expect(result.error.to_s).to eq('locked')
    ensure
      Spree.hooks.clear!
    end

    context 'on a placed order that has been paid in full' do
      let(:order) { create(:completed_order_with_totals, store: @default_store, line_items_count: 2) }

      before do
        create(:payment, amount: order.total, order: order, status: 'completed')
        order.update_column(:payment_total, order.total)
        order.update_statuses!
      end

      it 'takes the removed line out of the totals and re-derives the payment status' do
        removed_amount = line_item.amount
        total_before = order.total

        result = described_class.call(order: order, line_item: line_item)

        expect(result).to be_success
        order.reload
        expect(order.item_total).to eq(order.line_items.sum(&:amount))
        expect(order.total).to eq(total_before - removed_amount)
        expect(order.payment_status).to eq('overcharged')
      end
    end
  end
end
