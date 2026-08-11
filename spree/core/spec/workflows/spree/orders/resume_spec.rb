require 'spec_helper'

module Spree
  RSpec.describe Orders::Resume do
    let(:store) { @default_store }
    let(:order) { create(:completed_order_with_totals, store: store) }

    before { Orders::Cancel.call(order: order) }

    it 'restores the order and its fulfillments to their pre-cancel statuses' do
      result = described_class.call(order: order.reload)

      expect(result).to be_success
      expect(result.value.status).to eq('placed')
      expect(order.reload.fulfillments.map(&:status)).to all(eq('unfulfilled'))
    end

    it 'publishes order.resumed after commit', :events do
      allow(Spree::Events).to receive(:publish)
      described_class.call(order: order.reload)
      expect(Spree::Events).to have_received(:publish).with('order.resumed', any_args)
    end

    it 'dispatches the after_resume hook with the workflow context' do
      seen = nil
      Spree.hooks.register('orders.resume.after_resume') { |hook_context| seen = hook_context.order }
      described_class.call(order: order.reload)

      expect(seen&.id).to eq(order.id)
    ensure
      Spree.hooks.clear!
    end

    it 'fails on an order that is not canceled' do
      placed = create(:completed_order_with_totals, store: store)
      expect(described_class.call(order: placed)).to be_failure
    end
  end
end
