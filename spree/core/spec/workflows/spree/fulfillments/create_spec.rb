require 'spec_helper'

module Spree
  describe Fulfillments::Create do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:source_shipment) { order.fulfillments.first }
    let(:stock_location) { source_shipment.stock_location }
    let(:line_items) { order.line_items.sort_by(&:id) }

    let(:execute) { subject.call(**params) }
    let(:params) { { order: order, stock_location: stock_location } }
    let(:fulfillment) { execute.value }

    # Cancelling a parcel ends that attempt to ship, not the obligation. With
    # no way to revive the canceled record, a new fulfillment is the only path
    # left for its goods — so its units must be on offer, and the stock it
    # released on cancellation must be promised again.
    describe 'after a fulfillment is canceled' do
      let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 1) }
      let(:variant) { line_items.first.variant }

      before { Spree.fulfillment_cancel_workflow.call(fulfillment: source_shipment) }

      it 'offers the canceled units to a new fulfillment and promises the stock afresh' do
        expect(source_shipment.reload).to be_canceled

        expect(execute.success?).to eq(true)
        expect(fulfillment.fulfillment_items.sum(:quantity)).to eq(line_items.sum(&:quantity))
        expect(fulfillment.allocated_quantities[variant.id].to_i).to eq(line_items.sum(&:quantity))
        expect(fulfillment).to be_unfulfilled
      end

      it 'lets the order be shipped again' do
        execute
        # The factory never puts the goods on the shelf, and a dispatch the
        # shelf cannot cover is refused — so stock it, as a real placement did.
        fulfillment.stock_location.stock_level_or_create(variant).update_column(:count_on_hand, 10)

        result = Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

        expect(result.success?).to eq(true), result.error.to_s
        expect(fulfillment.reload).to be_fulfilled
      end
    end

    describe 'moving all unfulfilled items (items omitted)' do
      it 'creates a fulfillment holding every unshipped unit and destroys the drained source' do
        expect(execute.success?).to eq(true)
        expect(fulfillment).to be_kind_of(Spree::Shipment)
        expect(order.reload.shipments).to contain_exactly(fulfillment)
        expect(fulfillment.inventory_units.sum(:quantity)).to eq(line_items.sum(&:quantity))
      end

      it 'keeps the order total unchanged' do
        # Shipment cost must match what the rate calculator would produce —
        # pending fulfillments get re-priced by the standard rate machinery
        # (same as /split), so only a calculator-aligned cost is stable.
        order = create(:order_ready_to_ship, store: store, line_items_count: 2, shipment_cost: 10)

        expect { subject.call(order: order, stock_location: order.fulfillments.first.stock_location) }.
          not_to change { order.reload.total }
      end

      # No longer derived from the order's payment state — a new fulfillment
      # starts unfulfilled and stays there until someone hands it over.
      it 'starts unfulfilled' do
        expect(fulfillment.state).to eq('unfulfilled')
      end

      it 'assigns the order ship address' do
        expect(fulfillment.address_id).to eq(order.ship_address_id)
      end
    end

    describe 'explicit items' do
      let(:params) do
        {
          order: order,
          stock_location: stock_location,
          items: [{ line_item: line_items.first, quantity: 1 }],
          tracking: 'INPOST-123'
        }
      end

      it 'moves only the requested items and keeps the source shipment' do
        expect(execute.success?).to eq(true)
        expect(order.reload.shipments).to contain_exactly(source_shipment, fulfillment)
        expect(fulfillment.inventory_units.sum(:quantity)).to eq(1)
        expect(fulfillment.inventory_units.first.line_item).to eq(line_items.first)
        expect(source_shipment.reload.inventory_units.where(line_item: line_items.first).sum(:quantity)).to eq(0)
        expect(fulfillment.tracking).to eq('INPOST-123')
        # Pending fulfillments are priced by the standard rate machinery.
        expect(fulfillment.cost).to eq(fulfillment.selected_shipping_rate.cost)
      end

      context 'with a quantity larger than a single unit' do
        let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 1) }

        before { line_items.first.inventory_units.first.update!(quantity: 3) }

        it 'splits the unit, leaving the remainder on the source shipment' do
          params[:items] = [{ line_item: line_items.first, quantity: 2 }]

          expect(execute.success?).to eq(true)
          expect(fulfillment.inventory_units.sum(:quantity)).to eq(2)
          expect(source_shipment.reload.inventory_units.sum(:quantity)).to eq(1)
        end
      end
    end

    describe 'stock handling' do
      let(:variant) { line_items.first.variant }
      let(:other_stock_location) { create(:stock_location, name: 'External 3PL', backorderable_default: true) }
      let(:params) { { order: order, stock_location: other_stock_location } }

      # Moving units between fulfillments moves the promise, not the goods —
      # the shelf is untouched on both sides until a parcel leaves.
      it 'carries the allocation from the source location to the target' do
        stock_location.allocate(variant, 1, source_shipment)
        source_count = stock_location.count_on_hand(variant)

        expect(execute.success?).to eq(true)
        expect(stock_location.reload.stock_level(variant).allocated_count).to eq(0)
        expect(other_stock_location.reload.stock_level(variant).allocated_count).to eq(1)
        expect(stock_location.reload.count_on_hand(variant)).to eq(source_count)
      end

      # Allocation is keyed to the fulfillment, so a split has to carry it
      # across even when the origin does not change — otherwise the quantity
      # Fulfillments::Fulfill reads would sit on the wrong fulfillment.
      it 'carries the allocation across a same-location split' do
        stock_location.allocate(variant, 1, source_shipment)
        params[:stock_location] = stock_location
        params[:items] = [{ line_item: line_items.first, quantity: 1 }]

        expect(execute.success?).to eq(true)
        expect(fulfillment.allocated_quantity).to eq(1)
        expect(source_shipment.reload.allocated_quantity).to eq(0)
      end

      it 'carries nothing when the source holds no promise' do
        expect { execute }.not_to change { stock_location.reload.count_on_hand(variant) }
        expect(other_stock_location.reload.stock_level(variant)&.allocated_count.to_i).to eq(0)
      end
    end

    describe 'delivery method' do
      let(:delivery_method) { create(:shipping_method) }
      let(:params) { { order: order, stock_location: stock_location, delivery_method: delivery_method } }

      it 'keeps the delivery method selected through the rate refresh' do
        expect(execute.success?).to eq(true)
        expect(fulfillment.delivery_method).to eq(delivery_method)
      end

      it "inherits the drained source's delivery method when none is given" do
        original_method = source_shipment.delivery_method
        result = subject.call(order: order, stock_location: stock_location)

        expect(result.success?).to eq(true)
        expect(result.value.delivery_method).to eq(original_method)
      end

      it 'inherits the first non-nil method when draining sources with different carriers' do
        other_method = create(:shipping_method)
        second_source = order.shipments.create!(stock_location: stock_location)
        second_source.add_shipping_method(other_method, true)
        line_items.last.inventory_units.update_all(shipment_id: second_source.id)
        first_source_method = source_shipment.delivery_method

        result = subject.call(order: order, stock_location: stock_location, status: 'shipped')

        expect(result.success?).to eq(true)
        expect(order.reload.shipments).to contain_exactly(result.value)
        expect(result.value.delivery_method).to eq(first_source_method)
      end

      it 'does not inherit a method from partially drained sources' do
        result = subject.call(
          order: order,
          stock_location: stock_location,
          status: 'shipped',
          items: [{ line_item: line_items.first, quantity: 1 }]
        )

        expect(result.success?).to eq(true)
        expect(result.value.delivery_method).to be_nil
      end
    end

    describe 'explicit cost' do
      let(:params) do
        { order: order, stock_location: stock_location, status: 'shipped', cost: '7.42' }
      end

      it 'freezes the given cost instead of the inherited one' do
        expect(execute.success?).to eq(true)
        expect(fulfillment.cost).to eq(BigDecimal('7.42'))
        expect(order.reload.shipment_total).to eq(BigDecimal('7.42'))
      end

      it 'prices the carrier rate at the given cost' do
        params[:delivery_method] = create(:shipping_method)

        expect(execute.success?).to eq(true)
        expect(fulfillment.selected_shipping_rate.cost).to eq(BigDecimal('7.42'))
      end

      it 'treats a blank cost as omitted, inheriting the drained cost' do
        original_cost = source_shipment.cost
        params[:cost] = ''

        expect(execute.success?).to eq(true)
        expect(fulfillment.cost).to eq(original_cost)
      end

      it 'rejects a negative cost' do
        params[:cost] = -5

        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to eq(Spree.t('fulfillments.errors.invalid_cost'))
      end

      it 'rejects a non-numeric cost' do
        params[:cost] = 'free'

        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to eq(Spree.t('fulfillments.errors.invalid_cost'))
      end

      it 'rejects mixed alphanumeric garbage instead of stripping it' do
        params[:cost] = '12 boxes'

        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to eq(Spree.t('fulfillments.errors.invalid_cost'))
      end
    end

    describe "status: 'shipped'" do
      let(:params) { { order: order, stock_location: stock_location, status: 'shipped', tracking: 'DPD-42' } }

      it 'registers the fulfillment as already shipped' do
        expect(execute.success?).to eq(true)
        expect(fulfillment.status).to eq('fulfilled')
        expect(fulfillment.shipped_at).to be_present
        expect(fulfillment.fulfillment_items.all? { |unit| unit.status == 'shipped' }).to eq(true)
        expect(order.reload.fulfillment_status).to eq('fulfilled')
      end

      it 'freezes the inherited cost and carrier, keeping the order total unchanged' do
        delivery_method = create(:shipping_method)
        params[:delivery_method] = delivery_method

        # Settle factory-persisted totals before measuring invariance.
        order.recalculate_totals!
        original_total = order.reload.total
        source_shipment_cost = source_shipment.reload.cost

        expect(execute.success?).to eq(true)
        expect(fulfillment.cost).to eq(source_shipment_cost)
        expect(fulfillment.selected_shipping_rate.cost).to eq(source_shipment_cost)
        expect(fulfillment.selected_shipping_rate.delivery_method).to eq(delivery_method)
        expect(order.reload.total).to eq(original_total)
      end

      context 'when the order is not paid' do
        let(:order) { create(:order_ready_to_ship, store: store, with_payment: false) }

        it 'bypasses the paid-order readiness gate' do
          order.payments.delete_all
          order.update_column(:payment_status, 'balance_due')

          expect(execute.success?).to eq(true)
          expect(fulfillment.status).to eq('fulfilled')
        end
      end

      context 'with backordered units' do
        before do
          source_shipment.inventory_units.update_all(status: 'backordered')
        end

        it 'fills backorders before shipping' do
          expect(execute.success?).to eq(true)
          expect(fulfillment.status).to eq('fulfilled')
          expect(fulfillment.fulfillment_items.all? { |unit| unit.status == 'shipped' }).to eq(true)
        end
      end
    end

    describe 'failures' do
      it 'rejects a non-completed order' do
        incomplete = create(:order_with_line_items, store: store)
        result = subject.call(order: incomplete, stock_location: stock_location)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.order_not_completed'))
      end

      it 'rejects a canceled order' do
        order.update_columns(status: 'canceled', canceled_at: Time.current)
        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to eq(Spree.t('fulfillments.errors.order_canceled'))
      end

      it 'rejects an unknown status' do
        params[:status] = 'ready'
        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to eq(Spree.t('fulfillments.errors.invalid_status'))
      end

      it 'rejects a quantity above the unfulfilled quantity' do
        params[:items] = [{ line_item: line_items.first, quantity: 99 }]

        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to include('exceeds its unfulfilled quantity')
        expect(order.reload.shipments).to contain_exactly(source_shipment)
      end

      it 'rejects a non-positive quantity' do
        params[:items] = [{ line_item: line_items.first, quantity: 0 }]

        expect(execute.success?).to eq(false)
        expect(execute.error.to_s).to include('must be a positive integer')
      end

      it 'rejects an order with nothing left to fulfill' do
        shipped = create(:shipped_order, store: store)
        result = subject.call(order: shipped, stock_location: shipped.shipments.first.stock_location)

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.no_items_to_fulfill'))
      end
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto before any fulfillment is created' do
        Spree.hooks.register('fulfillments.create.validate') { |flow| flow.reject!('outside the cut-off window') }

        result = execute

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq('outside the cut-off window')
        expect(order.reload.shipments.count).to eq(1)
      end

      it 'merges provider payload from get_provider_data handlers' do
        Spree.hooks.register('fulfillments.create.get_provider_data') { |_flow| { carrier_account: 'acct_1' } }
        Spree.hooks.register('fulfillments.create.get_provider_data') { |_flow| { service_level: 'express' } }

        seen = nil
        Spree.hooks.register('fulfillments.create.after_create') { |flow| seen = flow.provider_data }

        expect(execute.success?).to eq(true)
        expect(seen).to eq(carrier_account: 'acct_1', service_level: 'express')
      end

      it 'exposes the created fulfillment to after_create' do
        seen = nil
        Spree.hooks.register('fulfillments.create.after_create') { |flow| seen = flow.fulfillment }

        execute

        expect(seen).to be_a(Spree::Fulfillment)
        expect(seen).to be_persisted
      end
    end
  end
end
