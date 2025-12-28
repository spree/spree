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

    it 'publishes order.completed event when finalizing' do
      expect(order).to receive(:publish_event).with('order.completed')
      allow(order).to receive(:publish_event).with(anything)

      order.finalize!
    end
  end

  describe '#cancel' do
    let(:order) { build(:order) }
    let!(:variant) { create(:variant) }
    let!(:inventory_units) { create_list(:inventory_unit, 2, variant: variant) }
    let!(:shipment) { create(:shipment) }
    let!(:line_items) { create_list(:line_item, 2, order: order, price: 10) }

    before do
      allow(shipment).to receive_messages inventory_units: inventory_units, order: order
      allow(order).to receive_messages shipments: [shipment]

      allow(order.line_items).to receive(:find_by).with(hash_including(:variant_id)) { line_items.first }

      allow(order).to receive_messages completed?: true
      allow(order).to receive_messages allow_cancel?: true

      shipments = [shipment]
      allow(order).to receive_messages shipments: shipments
      allow(shipments).to receive_messages states: []
      allow(shipments).to receive_messages ready: []
      allow(shipments).to receive_messages pending: []
      allow(shipments).to receive_messages shipped: []
      allow(shipments).to receive_message_chain(:sum, :cost).and_return(shipment.cost)

      allow_any_instance_of(Spree::OrderUpdater).to receive(:update_adjustment_total).and_return(10)
    end

    it 'publishes order.canceled event when canceling' do
      allow(shipment).to receive(:cancel!)
      allow(order).to receive :restock_items!

      expect(order).to receive(:publish_event).with('order.canceled')
      allow(order).to receive(:publish_event).with(anything)

      order.cancel!
    end
  end
end
