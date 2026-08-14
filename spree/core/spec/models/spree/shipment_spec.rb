require 'spec_helper'

describe Spree::Shipment, type: :model do
  it_behaves_like 'lifecycle events'

  let(:inventory_units) { create_list(:inventory_unit, 2) }
  let(:variant) { line_item.variant }
  let!(:line_item) { create(:line_item) }
  let(:shipment) do
    create(:shipment, number: 'H21265865494', cost: 1, state: 'unfulfilled', stock_location: create(:stock_location)).tap do |shipment|
      allow(shipment).to receive_messages order: order
      allow(shipment).to receive_messages(delivery_method: shipping_method, shipping_method: shipping_method)
    end
  end
  let(:shipping_method) { create(:shipping_method, name: 'UPS') }
  let!(:order) { create(:order, number: 'S12345', store: store) }
  let(:store) { @default_store }

  before do
    allow(order).to receive_messages(backordered?: false, canceled?: false, can_ship?: true, paid?: false, touch_later: false)
    allow(inventory_units.first).to receive_messages backordered?: false
    allow(inventory_units.first).to receive_messages backordered?: true
  end

  it_behaves_like 'metadata'

  describe 'precision of pre_tax_amount' do
    before { line_item.update(pre_tax_amount: 4.2051) }

    it 'keeps four digits of precision even when reloading' do
      # prevent it from updating pre_tax_amount
      allow_any_instance_of(Spree::LineItem).to receive(:update_tax_charge)
      expect(line_item.reload.pre_tax_amount).to eq(4.2051)
    end
  end

  describe '#digital?' do
    it 'returns true if the delivery method is digital' do
      shipment.delivery_method.fulfillment_provider = 'Spree::FulfillmentProvider::Digital'
      expect(shipment.digital?).to eq(true)
    end

    it 'returns false if the delivery method is not digital' do
      expect(shipment.digital?).to eq(false)
    end

    context 'when shipping method is nil' do
      let(:shipping_method) { nil }

      it 'returns false if shipping method is nil' do
        expect(shipment.digital?).to eq(false)
      end
    end
  end

  describe '#name' do
    it 'returns the shipment number and shipping method name' do
      expect(shipment.name).to eq('H21265865494 UPS')
    end
  end

  describe '#tracked?' do
    it 'returns true if the shipment is tracked' do
      expect(shipment.tracked?).to eq(true)
    end

    context 'when the shipment is not tracked' do
      let(:shipment) { build(:shipment, number: nil, tracking: nil) }

      it 'returns false' do
        expect(shipment.tracked?).to eq(false)
      end
    end
  end

  describe '#partial?' do
    subject { shipment.partial? }

    let(:shipment) { create(:shipment, order: order) }

    let!(:line_item) { create(:line_item, quantity: 5, order: order) }
    let(:order) { create(:order) }

    context 'when all products are included in the shipment' do
      it { is_expected.to be(false) }
    end

    context 'when not all products are included in the shipment' do
      before do
        shipment.inventory_units.first.update!(quantity: 3)
      end

      it { is_expected.to be(true) }
    end
  end

  # Regression test for #4063
  context 'number generation' do
    let(:shipment) { create(:shipment, stock_location: create(:stock_location)) }

    before do
      allow(order).to receive :recalculate_totals!
    end

    it 'derives the number from the order it belongs to' do
      expect(shipment.number).to eq("#{shipment.order.number}-F1")
    end
  end

  it 'is backordered if one if its inventory_units is backordered' do
    allow(shipment).to receive_messages(fulfillment_items: inventory_units)
    expect(shipment).to be_backordered
  end

  describe 'status' do
    it 'starts unfulfilled' do
      expect(create(:shipment).status).to eq('unfulfilled')
    end

    it 'rejects a status outside the vocabulary' do
      shipment.status = 'ready'
      expect(shipment).not_to be_valid
    end

    # The payment-derived pending/ready split is gone: whether the order is
    # paid is asked when someone tries to hand the goods over, not baked into
    # the fulfillment's own status where a refund could move it backwards.
    it 'does not change when the order is unpaid' do
      shipment
      allow(order).to receive_messages(paid?: false)

      expect { order.update_statuses! }.not_to change { shipment.reload.status }
    end
  end

  # The guards are stated negatively — anything not yet handed over can be
  # fulfilled or canceled — precisely so a status an extension inserts before
  # `fulfilled` works with the core workflows out of the box.
  describe 'an added custom status' do
    around do |example|
      original = Spree::Fulfillment.statuses
      Spree::Fulfillment.add_status('in_production', after: 'unfulfilled')
      example.run
    ensure
      Spree::Fulfillment.statuses = original
    end

    it 'is valid, with a predicate and a scope' do
      shipment.status = 'in_production'

      expect(shipment).to be_valid
      expect(shipment).to be_in_production
      expect(Spree::Fulfillment.statuses).to include('in_production')
    end

    it 'can still be handed over' do
      shipment.update!(status: 'in_production')

      expect(shipment.can_fulfill?).to be true
    end

    it 'can still be recalled' do
      shipment.update!(status: 'in_production')

      expect(shipment.can_cancel?).to be true
    end

    it 'cannot skip straight to confirmed receipt' do
      shipment.update!(status: 'in_production')

      expect(shipment.can_mark_delivered?).to be false
    end
  end

  describe 'tracking_status' do
    it 'accepts a carrier status' do
      shipment.tracking_status = 'in_transit'
      expect(shipment).to be_valid
    end

    it 'rejects one outside the carrier vocabulary' do
      shipment.tracking_status = 'lost_in_space'
      expect(shipment).not_to be_valid
    end

    it 'is optional' do
      shipment.tracking_status = nil
      expect(shipment).to be_valid
    end
  end

  context 'display_amount' do
    it 'retuns a Spree::Money' do
      allow(shipment).to receive(:cost).and_return(21.22)
      expect(shipment.display_amount).to eq(Spree::Money.new(21.22))
    end
  end

  context 'display_final_price' do
    it 'retuns a Spree::Money' do
      allow(shipment).to receive(:final_price).and_return(21.22)
      expect(shipment.display_final_price).to eq(Spree::Money.new(21.22))
    end
  end

  context 'display_item_cost' do
    it 'retuns a Spree::Money' do
      allow(shipment).to receive(:item_cost).and_return(21.22)
      expect(shipment.display_item_cost).to eq(Spree::Money.new(21.22))
    end
  end

  describe '#item_cost' do
    def create_shipment(order, stock_location)
      order.shipments.create(stock_location_id: stock_location.id).inventory_units.create(
        order_id: order.id,
        variant_id: order.line_items.first.variant_id,
        line_item_id: order.line_items.first.id
      )
    end

    it 'equals shipment line items amount with tax' do
      order = create(:order_with_line_item_quantity, line_items_quantity: 2)

      stock_location = create(:stock_location)

      create_shipment(order, stock_location)
      create_shipment(order, stock_location)

      # 10% additional tax on the 20.00 line
      order.line_items.first.update_columns(adjustment_total: 2.0, additional_tax_total: 2.0)

      expect(order.fulfillments.first.item_cost).to eq(11.0)
      expect(order.shipments.last.item_cost).to eq(11.0)
    end

    it 'equals line items final amount with tax' do
      shipment = create(:shipment, order: create(:order_with_line_item_quantity, line_items_quantity: 2))
      shipment.order.line_items.first.update_columns(adjustment_total: 2.0, additional_tax_total: 2.0)
      expect(shipment.item_cost).to eq(22.0)
    end
  end

  describe '#item_quantity' do
    it 'returns the sum of all manifest quantities with multiple quantities per line_item' do
      order = create(:order)
      variant1 = create(:variant)
      variant2 = create(:variant)
      create(:line_item, order: order, variant: variant1, quantity: 3)
      create(:line_item, order: order, variant: variant2, quantity: 2)
      shipment = create(:shipment, order: order)
      expect(shipment.item_quantity).to eq(5)
    end

    it 'returns the sum of all manifest quantities with single quantity per line_item' do
      order = create(:order)
      variant1 = create(:variant)
      variant2 = create(:variant)
      create(:line_item, order: order, variant: variant1, quantity: 1)
      create(:line_item, order: order, variant: variant2, quantity: 1)
      shipment = create(:shipment, order: order)
      expect(shipment.item_quantity).to eq(2)
    end

    it 'returns only the sum of items in the specific shipment, not in other shipments' do
      order = create(:order)
      variant1 = create(:variant)
      variant2 = create(:variant)
      line_item1 = create(:line_item, order: order, variant: variant1, quantity: 2)
      line_item2 = create(:line_item, order: order, variant: variant2, quantity: 4)

      # First shipment for line_item1
      shipment1 = create(:shipment, order: order)
      shipment1.inventory_units.delete_all
      shipment1.set_up_inventory('on_hand', variant1, order, line_item1, 2)

      # Second shipment for line_item2
      shipment2 = create(:shipment, order: order)
      shipment2.inventory_units.delete_all
      shipment2.set_up_inventory('on_hand', variant2, order, line_item2, 4)

      expect(shipment1.item_quantity).to eq(2)
      expect(shipment2.item_quantity).to eq(4)
    end

    it 'returns 0 if there are no items in the shipment' do
      shipment = create(:shipment)
      expect(shipment.item_quantity).to eq(0)
    end
  end

  describe '#item_weight' do
    it 'equals line items weight' do
      order = create(:order)
      variant = create(:variant, weight: 10)
      line_item = create(:line_item, order: order, variant: variant, quantity: 2)
      shipment = create(:shipment, order: order)
      expect(shipment.item_weight).to eq(20.0)
    end
  end

  describe '#weight_unit' do
    it 'equals line items weight unit' do
      order = create(:order)
      variant = create(:variant, weight: 10, weight_unit: 'kg')
      line_item = create(:line_item, order: order, variant: variant, quantity: 2)
      shipment = create(:shipment, order: order)
      expect(shipment.weight_unit).to eq('kg')
    end
  end

  it '#discounted_cost' do
    shipment = create(:shipment)
    shipment.cost = 10
    shipment.promo_total = -1
    expect(shipment.discounted_cost).to eq(9)
  end

  describe '#taxable_basis' do
    let(:shipment) { create(:shipment).tap { |s| s.cost = 10 } }

    it 'is the discounted cost' do
      shipment.promo_total = -1
      expect(shipment.taxable_basis).to eq(9)
    end

    it 'never goes below zero when discounts exceed the cost' do
      shipment.promo_total = -15
      expect(shipment.taxable_basis).to eq(0)
    end
  end

  it '#tax_total with included taxes' do
    shipment = Spree::Shipment.new
    expect(shipment.tax_total).to eq(0)
    shipment.included_tax_total = 10
    expect(shipment.tax_total).to eq(10)
  end

  it '#tax_total with additional taxes' do
    shipment = Spree::Shipment.new
    expect(shipment.tax_total).to eq(0)
    shipment.additional_tax_total = 10
    expect(shipment.tax_total).to eq(10)
  end

  it '#final_price' do
    shipment = Spree::Shipment.new
    shipment.cost = 10
    shipment.adjustment_total = -2
    shipment.included_tax_total = 1
    expect(shipment.final_price).to eq(8)
  end

  describe '#free?' do
    let!(:order) { create(:order) }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }

    it 'returns true if final_price is equal to 0' do
      shipment.adjustment_total = -10
      expect(shipment.free?).to eq(true)
    end

    it 'returns when Free Shipping promotion is applied' do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      expect(order.promotions).to include(free_shipping_promotion)
      expect(shipment.free?).to eq(true)
    end
  end

  describe '#with_free_shipping_promotion?' do
    let!(:order) { create(:order) }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }

    it 'returns true when Free Shipping promotion is applied' do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      expect(order.promotions).to include(free_shipping_promotion)
      expect(shipment.with_free_shipping_promotion?).to eq(true)
    end

    it 'returns false otherwise' do
      expect(shipment.with_free_shipping_promotion?).to eq(false)
    end
  end

  describe '#store' do
    let(:store) { @default_store }
    let!(:order) { create(:order, store: store) }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }

    it 'return order store' do
      expect(shipment.store).to eq(store)
    end
  end

  describe '#currency' do
    let!(:order) { create(:order, currency: 'EUR') }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }

    it 'return order currency' do
      expect(shipment.currency).to eq('EUR')
    end
  end

  context 'manifest' do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { Spree::Orders::AddItem.call(order: order, variant: variant).value }
    let!(:shipment) { order.rebuild_fulfillments!.first }

    it 'returns variant expected' do
      expect(shipment.manifest.first.variant).to eq variant
    end

    context 'variant was removed' do
      before { variant.destroy }

      it 'still returns variant expected' do
        expect(shipment.manifest.first.variant).to eq variant
      end
    end

    context 'when an inventory unit has no associated line item' do
      let(:other_variant) { create(:variant) }

      before do
        # Simulate an orphaned inventory unit (e.g. line item deleted directly
        # in the DB or via an out-of-band script). Bypass validations so the
        # spec stays valid even if InventoryUnit gains a presence validation
        # on line_item later.
        orphan = shipment.inventory_units.build(
          state: 'on_hand',
          variant: other_variant,
          order: order,
          line_item: nil,
          quantity: 1
        )
        orphan.save(validate: false)
      end

      it 'skips the orphaned inventory unit instead of raising' do
        expect { shipment.manifest }.not_to raise_error

        manifest = shipment.manifest
        expect(manifest.length).to eq(1)
        expect(manifest.first.variant).to eq(variant)
        expect(manifest.first.line_item).to eq(line_item)
      end
    end
  end

  describe '#can_get_rates?' do
    let(:digital_shipping_method) { create(:digital_shipping_method) }
    let(:digital_product) { create(:digital_product) }
    let(:digital_line_item) { create(:line_item, variant: create(:variant, product: digital_product)) }

    it 'returns true if order is digital and it does not have a ship address' do
      order.ship_address = nil
      order.line_items = [digital_line_item]
      order.recalculate_totals!
      expect(order.digital?).to eq(true)
      expect(shipment.send(:can_get_rates?)).to be_truthy
    end

    it 'returns false if order has physical items and no ship address' do
      order.ship_address = nil
      create(:line_item, order: order)
      order.line_items.reload

      expect(order.digital?).to eq(false)
      expect(shipment.send(:can_get_rates?)).to be_falsey
    end

    it 'returns false when order\'s ship address is not valid' do
      order.ship_address = build(:address, address1: nil)
      create(:line_item, order: order)
      order.line_items.reload

      expect(order.digital?).to eq(false)
      expect(shipment.send(:can_get_rates?)).to be_falsey
    end

    it 'returns true when order\'s ship address is valid' do
      order.ship_address = build(:address)
      create(:line_item, order: order)
      order.line_items.reload

      expect(order.digital?).to eq(false)
      expect(shipment.send(:can_get_rates?)).to be_truthy
    end
  end

  context 'shipping_rates' do
    let(:shipment) { create(:shipment) }
    let(:shipping_method1) { create(:shipping_method) }
    let(:shipping_method2) { create(:shipping_method) }
    let(:shipping_rates) do
      [
        Spree::ShippingRate.new(shipping_method: shipping_method1, cost: 10.00, selected: true),
        Spree::ShippingRate.new(shipping_method: shipping_method2, cost: 20.00)
      ]
    end

    it 'returns shipping_method from selected shipping_rate' do
      shipment.shipping_rates.delete_all
      shipment.shipping_rates.create shipping_method: shipping_method1, cost: 10.00, selected: true
      expect(shipment.shipping_method).to eq shipping_method1
    end

    context 'refresh_rates' do
      let(:mock_estimator) { double('estimator', delivery_rates: shipping_rates) }

      before { allow(shipment).to receive(:can_get_rates?).and_return(true) }

      it 'requests new rates, and maintain shipping_method selection' do
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(mock_estimator)
        allow(shipment).to receive_messages(delivery_method: shipping_method2)

        expect(shipment.refresh_rates).to eq(shipping_rates)
        expect(shipment.reload.selected_shipping_rate.shipping_method_id).to eq(shipping_method2.id)
      end

      it 'handles no shipping_method selection' do
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(mock_estimator)
        allow(shipment).to receive_messages(delivery_method: nil)
        expect(shipment.refresh_rates).to eq(shipping_rates)
        expect(shipment.reload.selected_shipping_rate).not_to be_nil
      end

      # The previously chosen method can drop out of the new quote (audience
      # change, eligibility rule, zone edit). The fulfillment must fall back to
      # the estimator's own pick rather than end up with nothing selected.
      it 'falls back to the estimator default when the original method is no longer quoted' do
        dropped_method = create(:shipping_method)
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(mock_estimator)
        allow(shipment).to receive_messages(delivery_method: dropped_method)

        shipment.refresh_rates

        expect(shipment.reload.selected_shipping_rate).not_to be_nil
        expect(shipment.selected_shipping_rate.shipping_method_id).to eq(shipping_method1.id)
      end

      # A carrier method yields one rate per service, so re-quoting must keep
      # the customer's chosen SERVICE, not just any rate from the same method.
      it 'keeps the previously selected carrier service across a re-quote' do
        shipment.shipping_rates.delete_all
        shipment.delivery_rates.create!(delivery_method: shipping_method1, cost: 9.40,
                                        carrier: 'UPS', service_level: 'Ground', name: 'UPS Ground')
        shipment.delivery_rates.create!(delivery_method: shipping_method1, cost: 28.10, selected: true,
                                        carrier: 'UPS', service_level: 'NextDayAir', name: 'UPS NextDayAir')

        fresh_ground = Spree::DeliveryRate.new(delivery_method: shipping_method1, cost: 9.90,
                                               carrier: 'UPS', service_level: 'Ground', name: 'UPS Ground')
        fresh_express = Spree::DeliveryRate.new(delivery_method: shipping_method1, cost: 29.00,
                                                carrier: 'UPS', service_level: 'NextDayAir', name: 'UPS NextDayAir')
        fresh_estimator = double('estimator', delivery_rates: [fresh_ground, fresh_express])
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(fresh_estimator)
        allow(shipment).to receive_messages(delivery_method: shipping_method1)

        shipment.refresh_rates

        selected = shipment.reload.selected_delivery_rate
        expect(selected.service_level).to eq('NextDayAir')
        expect(selected.cost).to eq(29.00)
      end

      it 'does not refresh if shipment is shipped' do
        expect(Spree::Stock::Estimator).not_to receive(:new)
        shipment.shipping_rates.delete_all
        allow(shipment).to receive_messages(fulfilled?: true)
        expect(shipment.refresh_rates).to eq([])
      end

      it "can't get rates without a shipping address" do
        shipment.order.ship_address = nil
        expect(shipment.refresh_rates).to eq([])
      end

      context 'to_package' do
        let(:inventory_units) do
          [build(:inventory_unit, line_item: line_item, variant: variant, state: 'on_hand'),
           build(:inventory_unit, line_item: line_item, variant: variant, state: 'backordered')]
        end

        before do
          allow(shipment).to receive(:fulfillment_items) { inventory_units }
          allow(inventory_units).to receive_message_chain(:includes, :joins).and_return inventory_units
        end

        it 'uses symbols for states when adding contents to package' do
          package = shipment.to_package
          expect(package.on_hand.count).to eq 1
          expect(package.backordered.count).to eq 1
        end
      end
    end
  end

  describe '#update!' do
    it 'no longer recomputes the status from the order' do
      shipment.update_column(:status, 'fulfilled')
      allow(Spree::Deprecation).to receive(:warn)

      expect { shipment.update!(order) }.not_to change { shipment.reload.status }
    end

    it 'still writes attributes through ActiveRecord' do
      shipment.update!(tracking: 'XYZ')
      expect(shipment.reload.tracking).to eq('XYZ')
    end
  end

  context 'when order is completed' do

    before do
      allow(order).to receive_messages completed?: true
      allow(order).to receive_messages canceled?: false
    end

    context 'with inventory tracking' do
      before { stub_store_preferences(track_inventory_levels: true) }

      it 'validates with inventory' do
        shipment.inventory_units = [create(:inventory_unit)]
        expect(shipment.valid?).to be true
      end
    end

    context 'without inventory tracking' do
      before { stub_store_preferences(track_inventory_levels: false) }

      it 'validates with no inventory' do
        expect(shipment.valid?).to be true
      end
    end
  end

  describe '#cancel' do
    let(:inventory_unit) { create(:inventory_unit, state: 'on_hand', line_item: line_item, variant: variant, quantity: 1) }

    # Restocking is no longer a transition callback — it belongs to
    # Spree::Fulfillments::Cancel, so the event only moves the status.
    it 'cancels the shipment' do
      allow(shipment.order).to receive(:recalculate_totals!)

      shipment.status = 'unfulfilled'
      described_class.transaction { shipment.update!(status: 'canceled') }
      expect(shipment.status).to eq 'canceled'
    end

    # Restocking belongs to Spree::Fulfillments::Cancel now; the deprecated
    # shell is all that survives on the model. Covered by
    # spec/workflows/spree/fulfillments/cancel_spec.rb.
    it 'restocks the items through the deprecated shell' do
      allow(shipment).to receive(:fulfillment_items).and_return([inventory_unit])
      allow(shipment).to receive(:provider).and_return(instance_double(Spree::FulfillmentProvider::Manual, cancel_fulfillment: true))
      shipment.stock_location = create(:stock_location)
      expect(shipment.stock_location).to receive(:restock).with(variant, 1, shipment)
      shipment.after_cancel
    end

    context 'with backordered inventory units' do
      let(:order) { create(:order) }
      let(:variant) { create(:variant) }
      let(:other_order) { create(:order) }

      before do
        Spree::Orders::AddItem.call(order: order, variant: variant)
        order.rebuild_fulfillments!

        Spree::Carts::AddItem.call(order: other_order, variant: variant)
        other_order.rebuild_fulfillments!
      end

      it "doesn't fill backorders when restocking inventory units" do
        shipment = order.fulfillments.first
        expect(shipment.inventory_units.count).to eq 1
        expect(shipment.inventory_units.first).to be_backordered

        other_shipment = other_order.fulfillments.first
        expect(other_shipment.inventory_units.count).to eq 1
        expect(other_shipment.inventory_units.first).to be_backordered

        expect do
          Spree.fulfillment_cancel_workflow.call(fulfillment: shipment)
        end.not_to change { other_shipment.inventory_units.first.state }
      end
    end
  end

  describe '#resume' do
    let(:inventory_unit) { create(:inventory_unit, quantity: 1, line_item: line_item, variant: variant) }

    # One target now: the old machine asked the order's payment state to choose
    # between pending and ready, which is exactly the coupling that was removed.
    it 'returns a canceled shipment to unfulfilled regardless of payment' do
      allow(shipment.order).to receive(:recalculate_totals!)
      shipment.update_column(:status, 'canceled')

      Spree.fulfillment_resume_workflow.call(fulfillment: shipment)

      expect(shipment.reload.status).to eq 'unfulfilled'
    end

    it 'unstocks them items' do
      allow(shipment).to receive(:fulfillment_items).and_return([inventory_unit])
      shipment.stock_location = create(:stock_location)
      expect(shipment.stock_location).to receive(:unstock).with(variant, 1, shipment)
      shipment.after_resume
    end

    context 'for a shipment item that does not track inventory' do
      before { variant.update(track_inventory: false) }

      it 'skips unstocking the shipment item' do
        allow(shipment).to receive(:fulfillment_items).and_return([inventory_unit])
        shipment.stock_location = create(:stock_location)
        expect(shipment.stock_location).not_to receive(:unstock)
        shipment.after_resume
      end
    end
  end

  describe '#ship' do
    context 'when the shipment is canceled' do
      let(:shipment_with_inventory_units) { create(:shipment, order: create(:order_with_line_items), state: 'canceled') }
      let(:subject) { shipment_with_inventory_units.update!(status: 'fulfilled') }

      before do
        allow(order).to receive(:recalculate_totals!)
        allow(shipment_with_inventory_units).to receive_messages(require_inventory: false, update_order: true)
      end

      # Taking the units back off the shelf moved to
      # Spree::Fulfillments::Fulfill, so the bare transition no longer does it.
      # See spec/workflows/spree/fulfillments/fulfill_spec.rb for the behavior.
      it 'does not unstock on the bare transition' do
        expect(shipment_with_inventory_units.stock_location).not_to receive(:unstock)
        subject
      end
    end

    ['unfulfilled', 'canceled'].each do |status|
      context "from #{status}" do
        let(:paid_order) { create(:order_ready_to_ship) }
        let(:fulfillment) { paid_order.fulfillments.first }

        before { fulfillment.update_column(:status, status) }

        it 'updates fulfilled_at timestamp' do
          Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

          expect(fulfillment.reload.fulfilled_at).not_to be_nil
        end
      end
    end
  end


  context 'updates cost when selected shipping rate is present' do
    let(:shipment) { create(:shipment) }

    before { allow(shipment).to receive_message_chain :selected_delivery_rate, cost: 5 }

    it 'updates shipment totals' do
      shipment.update_amounts
      expect(shipment.reload.cost).to eq(5)
    end

    it 'leaves typed adjustment columns to the order recalculation' do
      create(:fee, order: shipment.order, fulfillment: shipment, label: 'Additional', amount: 5)
      shipment.order.recalculate_totals!
      expect(shipment.reload.adjustment_total).to eq(5)
    end
  end

  context 'changes shipping rate via general update' do
    let(:order) do
      Spree::Order.create(
        payment_total: 100, payment_state: 'paid', total: 100, item_total: 100
      )
    end

    let(:shipment) { Spree::Shipment.create order_id: order.id, stock_location: create(:stock_location) }

    let(:shipping_rate) do
      Spree::ShippingRate.create shipment_id: shipment.id, cost: 10
    end

    before do
      Spree::Fulfillments::Update.call(fulfillment: shipment, fulfillment_attributes: { selected_shipping_rate_id: shipping_rate.id })
    end

    it 'updates everything around order shipment total and state' do
      expect(shipment.cost.to_f).to eq 10
      expect(shipment.state).to eq 'unfulfilled'
      # The full recalculation derives item_total from real line items
      # (fabricated column values don't survive it) and statuses come from
      # the payment records via UpdateStatuses.
      expect(shipment.order.total.to_f).to eq(shipment.order.item_total.to_f + 10)
      expect(shipment.order.payment_status).to eq('none')
    end
  end

  describe '#selected_shipping_rate_id=' do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }
    let(:shipment) { order.fulfillments.first }
    let(:shipping_method_1) { create(:shipping_method) }
    let(:shipping_method_2) { create(:shipping_method) }

    before do
      shipment.shipping_rates.delete_all
      create(:shipping_rate, shipment: shipment, shipping_method: shipping_method_1, cost: 10, selected: true)
      create(:shipping_rate, shipment: shipment, shipping_method: shipping_method_2, cost: 20, selected: false)
      shipment.reload
      order.set_fulfillments_cost
    end

    it 'updates order totals when a different shipping rate is selected' do
      expect(order.shipment_total).to eq(10)

      # Select the more expensive shipping rate
      shipping_rate_2 = shipment.shipping_rates.find_by(shipping_method: shipping_method_2)
      shipment.selected_shipping_rate_id = shipping_rate_2.id

      order.reload
      expect(order.shipment_total).to eq(20)
    end

    it 'updates the shipment cost to match the selected shipping rate' do
      shipping_rate_2 = shipment.shipping_rates.find_by(shipping_method: shipping_method_2)
      shipment.selected_shipping_rate_id = shipping_rate_2.id

      expect(shipment.reload.cost).to eq(20)
    end
  end

  describe '#cost=' do
    it 'parses well-formed decimal strings' do
      shipment = build(:shipment, order: nil, stock_location: nil, cost: '7.42')

      expect(shipment.cost).to eq(BigDecimal('7.42'))
    end

    it 'raises on malformed strings instead of truncating them' do
      expect { build(:shipment, order: nil, stock_location: nil, cost: '12 boxes') }.
        to raise_error(ArgumentError)
    end

    it 'casts blank strings to the zero default' do
      shipment = build(:shipment, order: nil, stock_location: nil, cost: '')
      shipment.valid?

      expect(shipment.cost).to eq(0)
    end
  end

  describe '#tax_category' do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }
    let(:fulfillment) { order.fulfillments.first }
    let(:reduced_rate_category) { create(:tax_category, name: "Reduced #{Time.current.to_f}") }
    let(:delivery_method) { create(:shipping_method, tax_category: reduced_rate_category) }

    def select_rate(method)
      fulfillment.delivery_rates.destroy_all
      create(:delivery_rate, fulfillment: fulfillment, delivery_method: method, selected: true)
      fulfillment.reload
    end

    it "is the classification the merchant set on the delivery method" do
      select_rate(delivery_method)

      expect(fulfillment.tax_category).to eq(reduced_rate_category)
      expect(fulfillment.tax_category_id).to eq(reduced_rate_category.id)
    end

    # The classification used to be read through the selected rate's tax_rate,
    # so a method classified for a rate the merchant never configured in the
    # destination reported no category — and delivery was then taxed under the
    # store's default one.
    it 'answers even when no tax rate covers that category' do
      select_rate(delivery_method)

      expect(Spree::TaxRate.for_tax_category(reduced_rate_category)).to be_empty
      expect(fulfillment.tax_category).to eq(reduced_rate_category)
    end

    it 'is nil when the delivery method carries no classification' do
      select_rate(create(:shipping_method, tax_category: nil))

      expect(fulfillment.tax_category).to be_nil
      expect(fulfillment.tax_category_id).to be_nil
    end
  end

  describe '#selected_delivery_rate_id / #selected_delivery_rate_id=' do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }
    let(:shipment) { order.fulfillments.first }
    let(:rate) { create(:shipping_rate, shipment: shipment, cost: 20, selected: false) }

    it 'selects a rate by its prefixed ID and reads back the prefixed ID' do
      shipment.selected_delivery_rate_id = rate.prefixed_id

      expect(shipment.reload.selected_shipping_rate).to eq(rate)
      expect(shipment.selected_delivery_rate_id).to eq(rate.prefixed_id)
    end

    it 'selects a rate by its raw ID' do
      shipment.selected_delivery_rate_id = rate.id

      expect(shipment.reload.selected_shipping_rate).to eq(rate)
    end

    it "raises for a rate that doesn't belong to the shipment" do
      foreign_rate = create(:shipping_rate)

      expect { shipment.selected_delivery_rate_id = foreign_rate.prefixed_id }.
        to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'after_save' do
    context 'cost changes' do
      before do
        shipment.save!
        shipment.cost = shipment.cost + 10
      end

      it 'triggers the order recalculation' do
        expect(shipment.order).to receive(:recalculate_totals!)
        shipment.save
      end

      it 'does not trigger recalculation if shipment is fulfilled' do
        shipment.status = 'fulfilled'
        expect(shipment.order).not_to receive(:recalculate_totals!)
        shipment.save
      end
    end

    context 'cost does not change' do
      it 'does not trigger the order recalculation' do
        shipment.save!
        expect(shipment.order).not_to receive(:recalculate_totals!)
        shipment.save
      end
    end
  end

  context 'currency' do
    it 'returns the order currency' do
      expect(shipment.currency).to eq(order.currency)
    end
  end

  context 'nil costs' do
    it 'sets cost to 0' do
      shipment = Spree::Shipment.new
      shipment.valid?
      expect(shipment.cost).to eq 0
    end
  end

  describe '#tracking_url' do
    it 'uses shipping method to determine url' do
      allow(shipping_method).to receive(:build_tracking_url).with('1Z12345').and_return(:some_url)
      shipment.tracking = '1Z12345'

      expect(shipment.tracking_url).to eq(:some_url)
    end

    it 'returns the tracking value as-is when it is already a full URL' do
      shipment.tracking = 'https://carrier.example/track/ABC'

      expect(shipment.tracking_url).to eq('https://carrier.example/track/ABC')
    end

    it 'is nil without a tracking number' do
      shipment.tracking = nil

      expect(shipment.tracking_url).to be_nil
    end

    # The provider bought the label, so its tracker page wins over anything
    # derived — it is the one link guaranteed to show this parcel.
    it 'prefers the fulfillment provider answer' do
      allow(shipment.provider).to receive(:tracking_url).with(shipment).and_return('https://provider.example/t/1')
      shipment.tracking = 'RANDOM123'

      expect(shipment.tracking_url).to eq('https://provider.example/t/1')
    end

    it 'builds from the pinned carrier registry entry' do
      shipment.tracking = '421432'
      shipment.tracking_carrier = 'inpost'

      expect(shipment.tracking_url).to eq('https://inpost.pl/sledzenie-przesylek?number=421432')
    end

    # No method, no carrier, no provider — a recognisable number still yields
    # its carrier's page through the tracking_number gem.
    it 'falls back to detection from the number format' do
      allow(shipment).to receive(:delivery_method).and_return(nil)
      shipment.tracking = '1Z879E930346834440'

      expect(shipment.tracking_url).to include('ups.com')
    end
  end

  describe 'tracking carrier detection' do
    it 'pins the detected carrier when a recognisable number is saved' do
      shipment.update!(tracking: '1Z879E930346834440')

      expect(shipment.tracking_carrier).to eq('ups')
      expect(shipment.tracking_carrier_name).to eq('UPS')
    end

    it 'leaves an explicit pick alone' do
      shipment.update!(tracking: '1Z879E930346834440', tracking_carrier: 'inpost')

      expect(shipment.tracking_carrier).to eq('inpost')
      expect(shipment.tracking_carrier_name).to eq('InPost')
    end

    it 'pins nothing for an unrecognisable number' do
      shipment.update!(tracking: '421432')

      expect(shipment.tracking_carrier).to be_nil
    end

    it 'titleizes a carrier the registry does not know' do
      shipment.tracking_carrier = 'some_courier'

      expect(shipment.tracking_carrier_name).to eq('Some Courier')
    end
  end

  describe '#transfer_to_location' do
    # Order with 2 line items in order to be able to split one shipment into 2
    let(:order) { create(:completed_order_with_totals, line_items_count: 2, store: store) }
    let!(:stock_location) { create(:stock_location, propagate_all_variants: true, backorderable_default: true) }
    let(:variant) { order.line_items.first.variant }

    before do
      perform_enqueued_jobs(only: Spree::StockLocations::StockLevels::CreateJob)
      shipping_method = order.fulfillments.first.shipping_method
      shipping_method.calculator.preferences[:amount] = order.fulfillments.first.cost
      shipping_method.calculator.save!
    end

    it 'creates new shipment for same order' do
      shipment = order.fulfillments.first

      expect { shipment.transfer_to_location(variant, 1, stock_location).run! }.
        to change { order.reload.shipments.size }.from(1).to(2)
    end

    it 'sets the given stock location for new shipment' do
      shipment = order.fulfillments.first
      shipment.transfer_to_location(variant, 1, stock_location).run!

      new_shipment = order.reload.shipments.last

      expect(new_shipment.stock_location).not_to eq(shipment.stock_location)
    end

    it 'sets proper costs for new shipment' do
      shipment = order.fulfillments.first
      shipment.transfer_to_location(variant, 1, shipment.stock_location)

      new_shipment = order.reload.shipments.last
      # Cost must be the same since both come from the same stock location
      expect(new_shipment.cost).to eq(shipment.cost)
    end

    it 'updates `order.shipment_total` to the sum of shipments cost' do
      shipment = order.fulfillments.first
      shipment.transfer_to_location(variant, 1, shipment.stock_location)

      order.reload
      expect(order.shipment_total).to eq(order.shipments.sum(&:cost))
    end
  end

  context 'set up new inventory units' do
    let(:variant) { double('Variant', id: 9) }

    let(:params) do
      { variant_id: variant.id, status: 'on_hand', order_id: order.id, line_item_id: line_item.id, quantity: 1 }
    end

    before { allow(shipment).to receive_messages fulfillment_items: inventory_units }

    it 'associates variant and order' do
      expect(inventory_units).to receive(:create).with(params)
      shipment.set_up_inventory('on_hand', variant, order, line_item)
    end

    # A cart's id written into order_id dereferences as whatever ORDER shares
    # that id — during checkout the item silently linked itself to a stranger's
    # order, whose ship address then stood in for the customer's at rating,
    # and whose backorder queue could swallow the cart's units.
    it 'leaves order_id nil when the owner is a cart' do
      cart = create(:cart, store: @default_store)

      expect(inventory_units).to receive(:create).with(params.merge(order_id: nil))
      shipment.set_up_inventory('on_hand', variant, cart, line_item)
    end
  end

  # Regression test for #3349
  describe '#destroy' do
    it 'destroys linked delivery_rates' do
      reflection = Spree::Fulfillment.reflect_on_association(:delivery_rates)
      expect(reflection.options[:dependent]).to be(:delete_all)
    end
  end

  describe '.unfulfilled' do
    subject { described_class.unfulfilled }

    let!(:unfulfilled_shipments) { create_list(:shipment, 2, status: 'unfulfilled') }
    let!(:fulfilled_shipments) { create_list(:shipment, 2, status: 'fulfilled') }

    it 'returns shipments nobody has handed over yet' do
      expect(subject).to include(*unfulfilled_shipments)
      expect(subject).not_to include(*fulfilled_shipments)
    end

    # ready_or_pending survives one release as an alias, since the two statuses
    # it named both became unfulfilled.
    it 'is what the deprecated ready_or_pending scope returns' do
      expect(described_class.ready_or_pending).to match_array(subject)
    end
  end

  describe 'events', events: true do
    let(:order) { create(:order_ready_to_ship) }
    let(:shipment) { order.fulfillments.first }

    describe 'shipped state transition' do
      before { shipment.update_column(:tracking, 'TRACK123') }

      # The fulfilled event carries notify_customer metadata so an admin can
      # suppress the shipment email for one dispatch.
      it 'publishes shipment.shipped event' do
        expect(shipment).to receive(:publish_event).
          with('shipment.shipped', nil, hash_including(notify_customer: true))
        allow(shipment).to receive(:publish_event).with(any_args)

        shipment.publish_fulfillment_fulfilled_event
      end
    end

    describe 'canceled state transition' do
      it 'publishes shipment.canceled event' do
        expect(shipment).to receive(:publish_event).with('shipment.canceled')
        allow(shipment).to receive(:publish_event).with(anything)

        shipment.publish_fulfillment_canceled_event
      end
    end

    describe 'resumed state transition' do
      before { shipment.update!(status: 'canceled') }

      it 'publishes shipment.resumed event' do
        expect(shipment).to receive(:publish_event).with('shipment.resumed')
        allow(shipment).to receive(:publish_event).with(anything)

        shipment.publish_fulfillment_resumed_event
      end
    end
  end
end
