require 'spec_helper'

module Spree
  describe Variants::RemoveLineItemJob, :job do
    let!(:order) { create(:order_with_line_items) }
    let!(:line_item) { order.line_items.take }

    it 'removes the line item from the order' do
      expect {
        described_class.perform_now(line_item: line_item)
      }.to change { order.reload.line_items.count }.by(-1)
    end

    # Carts and draft orders have different validation contracts, so the job
    # has to pick the workflow that matches the line item's owner.
    it 'routes an order-owned line item through the order workflow' do
      expect(Spree::Orders::UpsertItems).to receive(:new).and_call_original
      expect(Spree::Carts::UpsertItems).not_to receive(:new)

      described_class.perform_now(line_item: line_item)
    end

    context 'with a cart-owned line item' do
      let!(:cart) { create(:cart, store: @default_store) }
      let!(:cart_line_item) { create(:line_item, cart: cart, order: nil) }

      it 'removes the line item from the cart' do
        expect {
          described_class.perform_now(line_item: cart_line_item)
        }.to change { cart.reload.line_items.count }.by(-1)
      end

      it 'routes through the cart workflow' do
        expect(Spree::Carts::UpsertItems).to receive(:new).and_call_original

        described_class.perform_now(line_item: cart_line_item)
      end

      # A vetoed removal succeeds on the cart side as a warning, so the job
      # would otherwise finish silently with the line still there.
      it 'reports a vetoed removal instead of finishing quietly' do
        Spree.hooks.register('carts.upsert_items.validate') { |flow| flow.reject!('keep it') }
        expect(Rails.error).to receive(:report).with(
          an_instance_of(described_class::RemovalRejected), hash_including(source: 'spree.variants.remove_line_item')
        )

        expect {
          described_class.perform_now(line_item: cart_line_item)
        }.not_to change { cart.reload.line_items.count }
      ensure
        Spree.hooks.clear!
      end
    end
  end
end
