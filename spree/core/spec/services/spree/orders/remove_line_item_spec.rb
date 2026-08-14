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
      }.not_to change { order.reload.line_items.count }

      expect(result).to be_failure
    ensure
      Spree.hooks.clear!
    end
  end
end
