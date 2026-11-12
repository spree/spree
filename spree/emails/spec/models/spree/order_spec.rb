require 'spec_helper'

describe Spree::Order, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:order, customer: user, store: store) }

  context 'when the order completes' do
    let(:order) { create(:order, email: 'test@example.com', store: store) }

    before do
      order.update_column :status, 'placed'
    end

    it 'publishes the order.placed event', events: true do
      expect(order).to receive(:publish_event).with('order.placed', kind_of(Hash), hash_including(:notify_customer))
      expect(order).to receive(:publish_event).with('order.completed', kind_of(Hash), hash_including(:notify_customer, deprecated_alias_of: 'order.placed'))
      allow(order).to receive(:publish_event).with(anything)
      allow(order).to receive(:publish_event).with(anything, anything)

      Spree.order_complete_workflow.call(order: order, payment_pending: true)
    end
  end
end
