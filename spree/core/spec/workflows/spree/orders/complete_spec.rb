require 'spec_helper'

module Spree
  describe Orders::Complete do
    let(:store) { @default_store }
    let(:order) { Spree::Order.create(email: 'test@example.com') }

    after { Spree::Config.set track_inventory_levels: true }

    it 'is idempotent — an already placed order halts successfully with no side effects' do
      order.update_columns(completed_at: Time.current, status: 'placed')

      expect(order).not_to receive(:touch)
      result = described_class.call(order: order)

      expect(result).to be_success
      expect(result.value).to eq(order)
    end

    it 'refuses a canceled order' do
      order.update_columns(status: 'canceled', canceled_at: Time.current)

      expect(described_class.call(order: order)).to be_failure
    end

    it 'sets completed_at and places the order' do
      result = described_class.call(order: order)

      expect(result).to be_success
      expect(order.completed_at).to be_present
      expect(order.status).to eq('placed')
    end

    it 'finalizes every fulfillment' do
      order.shipments.each do |shipment| # rubocop:disable RSpec/IteratedExpectation
        expect(shipment).to receive(:update!)
        expect(shipment).to receive(:finalize!)
      end
      described_class.call(order: order)
    end

    it 'decreases the stock for each variant in the fulfillments' do
      order.shipments.each do |shipment|
        expect(shipment.stock_location).to receive(:decrease_stock_for_variant)
      end
      described_class.call(order: order)
    end

    it 'leaves the fulfillment unfulfilled until someone hands it over' do
      Spree::Shipment.create(order: order, stock_location: create(:stock_location))
      order.shipments.reload

      allow(order).to receive_messages(paid?: true, complete?: true)
      described_class.call(order: order)
      order.reload

      expect(order.shipment_state).to eq('unfulfilled')
    end

    it 'does not sell inventory units if track_inventory_levels is false' do
      Spree::Config.set track_inventory_levels: false
      expect(Spree::InventoryUnit).not_to receive(:sell_units)
      described_class.call(order: order)
    end

    it 'freezes adjustment recalculation (order-level freeze)' do
      described_class.call(order: order)

      expect(Spree::Adjusters::Promotion).not_to receive(:adjust)
      order.recalculate_totals!
    end

    context 'order is considered risky' do
      before do
        allow_any_instance_of(Spree::Order).to receive_messages(is_risky?: true)
      end

      it 'changes state to risky', :events do
        expect { described_class.call(order: order) }.to change { order.reload.considered_risky }.to(true)
      end

      context 'and order is approved' do
        before do
          allow_any_instance_of(Spree::Order).to receive_messages(approved?: true)
        end

        it 'leaves the order placed' do
          described_class.call(order: order)
          expect(order.status).to eq 'placed'
        end
      end
    end

    context 'events', :events do
      let(:order) { create(:order_with_line_items, store: store) }

      it 'publishes order.placed with the deprecated order.completed alias' do
        expect(order).to receive(:publish_event).with('order.placed', hash_including(:notify_customer)).at_least(:once)
        expect(order).to receive(:publish_event).with('order.completed', hash_including(:notify_customer), { deprecated_alias_of: 'order.placed' }).at_least(:once)
        allow(order).to receive(:publish_event).with(anything)
        allow(order).to receive(:publish_event).with(anything, anything)

        described_class.call(order: order, payment_pending: true)
      end

      it 'enqueues RefreshMetricsJob for each product in the order' do
        product_count = order.line_items.map { |line_item| line_item.variant.product_id }.uniq.count

        expect do
          described_class.call(order: order, payment_pending: true)
          perform_enqueued_jobs(only: Spree::Events::SubscriberJob)
        end.to have_enqueued_job(Spree::Products::RefreshMetricsJob).exactly(product_count).times
      end
    end

    context 'order is not considered risky' do
      before do
        allow(order).to receive_messages(is_risky?: false)
      end

      it 'sets completed_at' do
        described_class.call(order: order)
        expect(order.completed_at).to be_present
      end
    end
  end
end
