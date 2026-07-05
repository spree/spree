require 'spec_helper'

describe Spree::Order, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, store: store) }

  context '#finalize!' do
    let(:order) { create(:order, email: 'test@example.com', store: store) }

    before do
      order.update_column :state, 'complete'
    end

    it 'publishes order.completed event when finalizing', events: true do
      expect(order).to receive(:publish_event).with('order.completed', hash_including(:notify_customer))
      allow(order).to receive(:publish_event).with(anything)
      allow(order).to receive(:publish_event).with(anything, anything)

      order.finalize!
    end
  end
end
