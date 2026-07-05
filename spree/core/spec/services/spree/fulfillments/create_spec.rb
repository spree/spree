require 'spec_helper'

module Spree
  describe Fulfillments::Create do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:source_shipment) { order.shipments.first }
    let(:stock_location) { source_shipment.stock_location }
    let(:line_items) { order.line_items.sort_by(&:id) }

    let(:execute) { subject.call(**params) }
    let(:params) { { order: order, stock_location: stock_location } }
    let(:fulfillment) { execute.value }

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

        expect { subject.call(order: order, stock_location: order.shipments.first.stock_location) }.
          not_to change { order.reload.total }
      end

      it 'sets the state from the order (paid order -> ready)' do
        expect(fulfillment.state).to eq('ready')
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

      it 'restocks the source location and unstocks the target for tracked variants' do
        source_count = stock_location.count_on_hand(variant)

        expect(execute.success?).to eq(true)
        expect(stock_location.reload.count_on_hand(variant)).to eq(source_count + 1)
        expect(other_stock_location.reload.count_on_hand(variant)).to eq(-1)
      end

      it 'does not touch stock when the location stays the same' do
        params[:stock_location] = stock_location
        expect { execute }.not_to change { stock_location.reload.count_on_hand(variant) }
      end
    end

    describe 'delivery method' do
      let(:delivery_method) { create(:shipping_method) }
      let(:params) { { order: order, stock_location: stock_location, delivery_method: delivery_method } }

      it 'keeps the delivery method selected through the rate refresh' do
        expect(execute.success?).to eq(true)
        expect(fulfillment.shipping_method).to eq(delivery_method)
      end

      it "inherits the drained source's delivery method when none is given" do
        original_method = source_shipment.shipping_method
        result = subject.call(order: order, stock_location: stock_location)

        expect(result.success?).to eq(true)
        expect(result.value.shipping_method).to eq(original_method)
      end

      it 'inherits the first non-nil method when draining sources with different carriers' do
        other_method = create(:shipping_method)
        second_source = order.shipments.create!(stock_location: stock_location)
        second_source.add_shipping_method(other_method, true)
        line_items.last.inventory_units.update_all(shipment_id: second_source.id)
        first_source_method = source_shipment.shipping_method

        result = subject.call(order: order, stock_location: stock_location, status: 'shipped')

        expect(result.success?).to eq(true)
        expect(order.reload.shipments).to contain_exactly(result.value)
        expect(result.value.shipping_method).to eq(first_source_method)
      end

      it 'does not inherit a method from partially drained sources' do
        result = subject.call(
          order: order,
          stock_location: stock_location,
          status: 'shipped',
          items: [{ line_item: line_items.first, quantity: 1 }]
        )

        expect(result.success?).to eq(true)
        expect(result.value.shipping_method).to be_nil
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
        expect(fulfillment.state).to eq('shipped')
        expect(fulfillment.shipped_at).to be_present
        expect(fulfillment.inventory_units.all? { |unit| unit.state == 'shipped' }).to eq(true)
        expect(order.reload.shipment_state).to eq('shipped')
      end

      it 'freezes the inherited cost and carrier, keeping the order total unchanged' do
        delivery_method = create(:shipping_method)
        params[:delivery_method] = delivery_method

        # Settle factory-persisted totals before measuring invariance.
        order.update_with_updater!
        original_total = order.reload.total
        source_shipment_cost = source_shipment.reload.cost

        expect(execute.success?).to eq(true)
        expect(fulfillment.cost).to eq(source_shipment_cost)
        expect(fulfillment.selected_shipping_rate.cost).to eq(source_shipment_cost)
        expect(fulfillment.selected_shipping_rate.shipping_method).to eq(delivery_method)
        expect(order.reload.total).to eq(original_total)
      end

      context 'when the order is not paid' do
        let(:order) { create(:order_ready_to_ship, store: store, with_payment: false) }

        it 'bypasses the paid-order readiness gate' do
          order.payments.delete_all
          order.update_column(:payment_state, 'balance_due')

          expect(execute.success?).to eq(true)
          expect(fulfillment.state).to eq('shipped')
        end
      end

      context 'with backordered units' do
        before do
          source_shipment.inventory_units.update_all(state: 'backordered')
        end

        it 'fills backorders before shipping' do
          expect(execute.success?).to eq(true)
          expect(fulfillment.state).to eq('shipped')
          expect(fulfillment.inventory_units.all? { |unit| unit.state == 'shipped' }).to eq(true)
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
        order.update_columns(state: 'canceled')
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
  end
end
