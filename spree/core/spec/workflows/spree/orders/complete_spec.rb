require 'spec_helper'

module Spree
  describe Orders::Complete do
    let(:store) { @default_store }
    let(:order) { Spree::Order.create(email: 'test@example.com') }

    # Regression: the rollup writes its vocabulary (none/authorized/...) via
    # update_columns, so the model's validation must accept it — otherwise the
    # first derived value poisons the order and completion 422s forever.
    it 'completes an order whose rollup already wrote a derived payment status' do
      draft = create(:order_ready_to_ship, store: store)
      draft.update_columns(status: 'draft', completed_at: nil, payment_status: 'authorized')

      result = described_class.call(order: draft, payment_pending: true)

      expect(result).to be_success
      expect(draft.reload.status).to eq('placed')
    end

    describe 'stock' do
      let(:draft) { create(:order_ready_to_ship, store: store, line_items_count: 1) }
      let(:fulfillment) { draft.fulfillments.first }
      let(:variant) { fulfillment.fulfillment_items.first.variant }
      let(:stock_level) { fulfillment.stock_location.stock_level(variant) }
      let(:quantity) { fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity) }

      before { draft.update_columns(status: 'draft', completed_at: nil) }

      # Placement promises stock; the shelf only empties when the parcel does.
      it 'allocates each fulfillment without touching the shelf' do
        count_on_hand_before = stock_level.reload.count_on_hand

        expect { described_class.call(order: draft, payment_pending: true) }.
          to change { stock_level.reload.allocated_count }.by(quantity)

        expect(stock_level.reload.count_on_hand).to eq(count_on_hand_before)
      end

      it 'records the fulfillment and its order on the movement' do
        described_class.call(order: draft, payment_pending: true)

        movement = stock_level.stock_movements.allocated.last
        expect(movement.fulfillment).to eq(fulfillment)
        expect(movement.order).to eq(draft)
        expect(movement.quantity).to eq(quantity)
      end
    end

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
      stub_store_preferences(track_inventory_levels: false)
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

    # The files-ready email subscribes to order.placed and bails when the order
    # has no links, so link creation moving after the publish would turn into
    # silence rather than a failure. Pin the ordering here.
    describe 'digital links and order.placed' do
      let(:digital_variant) { create(:variant) }
      let!(:digital_asset) { create(:digital_asset, variant: digital_variant) }

      before do
        order.line_items.create!(variant: digital_variant, quantity: 2, price: 10)
        order.recalculate_totals!
      end

      it 'has created the links by the time order.placed fires' do
        links_at_publish = nil

        allow_any_instance_of(Spree::Order).to receive(:publish_event).and_wrap_original do |original, *args|
          links_at_publish ||= original.receiver.digital_links.count if args.first == 'order.placed'
          original.call(*args)
        end

        described_class.call(order: order, payment_pending: true)

        expect(links_at_publish).to eq(2)
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
