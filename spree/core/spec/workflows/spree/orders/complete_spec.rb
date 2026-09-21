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

    it 'places a draft with a negotiated line at the negotiated price' do
      draft = create(:order_ready_to_ship, store: store, line_items_count: 1)
      draft.update_columns(status: 'draft', completed_at: nil)
      line_item = draft.line_items.first
      line_item.update_columns(price: 7.2, price_source: Spree::LineItem::MANUAL_PRICE_SOURCE)

      result = described_class.call(order: draft, payment_pending: true)

      expect(result).to be_success
      expect(line_item.reload.price).to eq(7.2)
      expect(line_item.price_source).to eq('manual')
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

    # An order raised from the admin never passes through a cart, so this is
    # the only place its sale gets filed under whoever made it.
    describe 'filing the sale under its seller' do
      let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
      let(:other_seller) { create(:seller, :approved, store: store, name: 'Quill Books') }

      # A draft order raised in the back office, whose sellers the caller
      # decides. Nil is the operator's own goods.
      def draft_for(*sellers, paid: true)
        draft = create(:order_ready_to_ship, store: store, line_items_count: sellers.size)
        draft.update_columns(status: 'draft', completed_at: nil, payment_status: nil)
        draft.line_items.reload.each_with_index do |line_item, index|
          assigned = sellers[index]
          line_item.variant.update!(seller: assigned)
          line_item.update_columns(seller_id: assigned&.id)
        end
        draft.reload.recalculate_totals!
        draft.payments.destroy_all
        # Settled before the division, as the money always is: the operator
        # took one payment against the whole order.
        create(:payment, order: draft, status: 'completed', amount: draft.reload.total) if paid
        draft.reload
      end

      it 'stamps a single seller onto the order' do
        draft = draft_for(seller, seller)

        result = described_class.call(order: draft, payment_pending: true)

        expect(result).to be_success
        expect(result.value).to be_a(Spree::Order)
        expect(draft.reload.seller_id).to eq(seller.id)
        expect(Spree::OrderGroup.count).to eq(0)
      end

      it 'leaves the operator\'s own order without a seller' do
        draft = draft_for(nil, nil)

        described_class.call(order: draft, payment_pending: true)

        expect(draft.reload.seller_id).to be_nil
        expect(Spree::OrderGroup.count).to eq(0)
      end

      it 'divides an order holding two sellers goods into one order each' do
        draft = draft_for(seller, other_seller)

        result = described_class.call(order: draft, payment_pending: true)

        expect(result).to be_success
        group = result.value
        expect(group).to be_a(Spree::OrderGroup)
        expect(group.orders.reload.map(&:seller_id)).to match_array([seller.id, other_seller.id])
        expect(group.orders.map(&:status).uniq).to eq(['placed'])
      end

      # The customer authorised one amount, so the children's totals have to
      # add back up to it rather than each being re-derived.
      it 'keeps the children totalling what the order was worth' do
        draft = draft_for(seller, other_seller)
        expected_total = draft.total

        group = described_class.call(order: draft, payment_pending: true).value

        expect(group.orders.reload.sum(&:total)).to eq(expected_total)
      end

      it 'records each child\'s share of the payment' do
        draft = draft_for(seller, other_seller)
        expected_total = draft.total

        group = described_class.call(order: draft, payment_pending: true).value

        expect(group.payment_splits.sum(:authorized_amount)).to eq(expected_total)
      end

      # Invoice-later has no money to apportion, so there are no shares to
      # write — and every child must still place and roll up a status rather
      # than stalling on payment nobody made.
      it 'divides an unpaid invoice-later order with no shares to record' do
        draft = draft_for(seller, other_seller, paid: false)

        group = described_class.call(order: draft, payment_pending: true).value

        expect(group.orders.reload.count).to eq(2)
        expect(group.payment_splits).to be_empty
        expect(group.orders.map(&:status).uniq).to eq(['placed'])
        expect(group.orders.map(&:payment_status).uniq).to eq(['none'])
      end

      it 'commissions each seller on their own order', :events do
        create(:commission_rate, store: store, value: 15)
        draft = draft_for(seller, other_seller)

        group = described_class.call(order: draft, payment_pending: true).value

        expect(Spree::CommissionLine.pluck(:seller_id)).to match_array([seller.id, other_seller.id])
        expect(group.orders.reload.map { |child| child.reload.commission_total }).to all(be_positive)
      end

      # The division adopts this order, so the flag the caller set on it in
      # memory has to survive — a freshly loaded child would silently email a
      # customer the operator asked not to notify.
      it 'keeps a silent completion silent when the order divides', :events do
        draft = draft_for(seller, other_seller)
        notified = []
        allow_any_instance_of(Spree::Order).to receive(:publish_event).and_wrap_original do |original, *args|
          notified << original.receiver.notify_customer if args.first == 'order.placed'
          original.call(*args)
        end

        described_class.call(order: draft, payment_pending: true, notify_customer: false)

        expect(notified).to all(be(false))
      end

      # A division interrupted after the first child was placed leaves siblings
      # in draft; nothing else ever places them, so the replay must.
      it 'places a sibling left behind by an interrupted division' do
        draft = draft_for(seller, other_seller)
        group = described_class.call(order: draft, payment_pending: true).value
        stranded = group.orders.reload.order(:id).last
        stranded.update_columns(status: 'draft', completed_at: nil)

        described_class.call(order: draft.reload, payment_pending: true)

        expect(stranded.reload.status).to eq('placed')
      end

      # Nothing retries a webhook that was never published.
      it 'announces the group on a replay that had nothing left to place', :events do
        draft = draft_for(seller, other_seller)
        described_class.call(order: draft, payment_pending: true)

        announced = 0
        allow_any_instance_of(Spree::OrderGroup).to receive(:publish_event) do |_, name, *|
          announced += 1 if name == 'order_group.completed'
        end

        described_class.call(order: draft.reload, payment_pending: true)

        expect(announced).to eq(1)
      end

      it 'divides once when the completion is replayed' do
        draft = draft_for(seller, other_seller)
        described_class.call(order: draft, payment_pending: true)

        expect { described_class.call(order: draft.reload, payment_pending: true) }.
          not_to change(Spree::OrderGroup, :count)
      end

      # A retried completion must not report one seller's order where the
      # first run reported the whole purchase.
      it 'answers a replay with the group it made the first time' do
        draft = draft_for(seller, other_seller)
        group = described_class.call(order: draft, payment_pending: true).value

        replayed = described_class.call(order: draft.reload, payment_pending: true)

        expect(replayed).to be_success
        expect(replayed.value).to eq(group)
      end
    end
  end
end
