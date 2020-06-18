require 'spec_helper'

describe Spree::Shipment, type: :model do
  let(:order) do
    mock_model Spree::Order, backordered?: false,
                             canceled?: false,
                             can_ship?: true,
                             currency: 'USD',
                             number: 'S12345',
                             paid?: false,
                             touch_later: false
  end
  let(:shipping_method) { create(:shipping_method, name: 'UPS') }
  let(:shipment) do
    shipment = Spree::Shipment.new(cost: 1, state: 'pending', stock_location: create(:stock_location))
    allow(shipment).to receive_messages order: order
    allow(shipment).to receive_messages shipping_method: shipping_method
    shipment.save
    shipment
  end

  let(:variant) { mock_model(Spree::Variant) }
  let(:line_item) { mock_model(Spree::LineItem, variant: variant) }

  def create_shipment(order, stock_location)
    order.shipments.create(stock_location_id: stock_location.id).inventory_units.create(
      order_id: order.id,
      variant_id: order.line_items.first.variant_id,
      line_item_id: order.line_items.first.id
    )
  end

  describe 'precision of pre_tax_amount' do
    let(:line_item) { create :line_item, pre_tax_amount: 4.2051 }

    it 'keeps four digits of precision even when reloading' do
      # prevent it from updating pre_tax_amount
      allow_any_instance_of(Spree::LineItem).to receive(:update_tax_charge)
      expect(line_item.reload.pre_tax_amount).to eq(4.2051)
    end
  end

  # Regression test for #4063
  context 'number generation' do
    before do
      allow(order).to receive :update_with_updater!
    end

    it 'generates a number containing a letter + 11 numbers' do
      expect(shipment.number[0]).to eq('H')
      expect(/\d{11}/.match(shipment.number)).not_to be_nil
      expect(shipment.number.length).to eq(12)
    end
  end

  it 'is backordered if one if its inventory_units is backordered' do
    allow(shipment).to receive_messages(inventory_units: [
                                          mock_model(Spree::InventoryUnit, backordered?: false),
                                          mock_model(Spree::InventoryUnit, backordered?: true)
                                        ])
    expect(shipment).to be_backordered
  end

  context '#determine_state' do
    it 'returns canceled if order is canceled?' do
      allow(order).to receive_messages canceled?: true
      expect(shipment.determine_state(order)).to eq 'canceled'
    end

    it 'returns pending unless order.can_ship?' do
      allow(order).to receive_messages can_ship?: false
      expect(shipment.determine_state(order)).to eq 'pending'
    end

    it 'returns pending if backordered' do
      allow(shipment).to receive_messages inventory_units: [mock_model(Spree::InventoryUnit, backordered?: true)]
      expect(shipment.determine_state(order)).to eq 'pending'
    end

    it 'returns shipped when already shipped' do
      allow(shipment).to receive_messages state: 'shipped'
      expect(shipment.determine_state(order)).to eq 'shipped'
    end

    it 'returns pending when unpaid' do
      expect(shipment.determine_state(order)).to eq 'pending'
    end

    it 'returns ready when paid' do
      allow(order).to receive_messages paid?: true
      expect(shipment.determine_state(order)).to eq 'ready'
    end

    it 'returns ready when Config.auto_capture_on_dispatch' do
      Spree::Config.auto_capture_on_dispatch = true
      expect(shipment.determine_state(order)).to eq 'ready'
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

  context '#item_cost' do
    it 'equals shipment line items amount with tax' do
      order = create(:order_with_line_item_quantity, line_items_quantity: 2)

      stock_location = create(:stock_location)

      create_shipment(order, stock_location)
      create_shipment(order, stock_location)

      create :tax_adjustment, adjustable: order.line_items.first, order: order

      expect(order.shipments.first.item_cost).to eq(11.0)
      expect(order.shipments.last.item_cost).to eq(11.0)
    end

    it 'equals line items final amount with tax' do
      shipment = create(:shipment, order: create(:order_with_line_item_quantity, line_items_quantity: 2))
      create :tax_adjustment, adjustable: shipment.order.line_items.first, order: shipment.order
      expect(shipment.item_cost).to eq(22.0)
    end
  end

  it '#discounted_cost' do
    shipment = create(:shipment)
    shipment.cost = 10
    shipment.promo_total = -1
    expect(shipment.discounted_cost).to eq(9)
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

  context '#free?' do
    let!(:order) { create(:order) }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship') }

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

  context '#store' do
    let(:store) { create(:store) }
    let!(:order) { create(:order, store: store) }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }

    it 'return order store' do
      expect(shipment.store).to eq(store)
    end
  end

  context '#currency' do
    let!(:order) { create(:order, currency: 'EUR') }
    let!(:shipment) { create(:shipment, cost: 10, order: order) }

    it 'return order currency' do
      expect(shipment.currency).to eq('EUR')
    end
  end

  context 'manifest' do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { Spree::Cart::AddItem.call(order: order, variant: variant).value }
    let!(:shipment) { order.create_proposed_shipments.first }

    it 'returns variant expected' do
      expect(shipment.manifest.first.variant).to eq variant
    end

    context 'variant was removed' do
      before { variant.destroy }

      it 'still returns variant expected' do
        expect(shipment.manifest.first.variant).to eq variant
      end
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
      let(:mock_estimator) { double('estimator', shipping_rates: shipping_rates) }

      before { allow(shipment).to receive(:can_get_rates?).and_return(true) }

      it 'requests new rates, and maintain shipping_method selection' do
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(mock_estimator)
        allow(shipment).to receive_messages(shipping_method: shipping_method2)

        expect(shipment.refresh_rates).to eq(shipping_rates)
        expect(shipment.reload.selected_shipping_rate.shipping_method_id).to eq(shipping_method2.id)
      end

      it 'handles no shipping_method selection' do
        expect(Spree::Stock::Estimator).to receive(:new).with(shipment.order).and_return(mock_estimator)
        allow(shipment).to receive_messages(shipping_method: nil)
        expect(shipment.refresh_rates).to eq(shipping_rates)
        expect(shipment.reload.selected_shipping_rate).not_to be_nil
      end

      it 'does not refresh if shipment is shipped' do
        expect(Spree::Stock::Estimator).not_to receive(:new)
        shipment.shipping_rates.delete_all
        allow(shipment).to receive_messages(shipped?: true)
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
          allow(shipment).to receive(:inventory_units) { inventory_units }
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

  context '#update!' do
    shared_examples_for 'immutable once shipped' do
      it 'remains in shipped state once shipped' do
        shipment.state = 'shipped'
        expect(shipment).to receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    shared_examples_for 'pending if backordered' do
      it 'has a state of pending if backordered' do
        allow(shipment).to receive_messages(inventory_units: [mock_model(Spree::InventoryUnit, backordered?: true)])
        expect(shipment).to receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context 'when order cannot ship' do
      before { allow(order).to receive_messages can_ship?: false }

      it "results in a 'pending' state" do
        expect(shipment).to receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context 'when order is paid' do
      before { allow(order).to receive_messages paid?: true }

      it "results in a 'ready' state" do
        expect(shipment).to receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_behaves_like 'immutable once shipped'
      it_behaves_like 'pending if backordered'
    end

    context 'when order has balance due' do
      before { allow(order).to receive_messages paid?: false }

      it "results in a 'pending' state" do
        shipment.state = 'ready'
        expect(shipment).to receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_behaves_like 'immutable once shipped'
      it_behaves_like 'pending if backordered'
    end

    context 'when order has a credit owed' do
      before { allow(order).to receive_messages payment_state: 'credit_owed', paid?: true }

      it "results in a 'ready' state" do
        shipment.state = 'pending'
        expect(shipment).to receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_behaves_like 'immutable once shipped'
      it_behaves_like 'pending if backordered'
    end

    context 'when shipment state changes to shipped' do
      before do
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:send_shipped_email)
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)
      end

      it 'calls after_ship' do
        shipment.state = 'pending'
        expect(shipment).to receive :after_ship
        allow(shipment).to receive_messages determine_state: 'shipped'
        expect(shipment).to receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end

      context 'when using the default shipment handler' do
        it "calls the 'perform' method" do
          shipment.state = 'pending'
          allow(shipment).to receive_messages determine_state: 'shipped'
          expect_any_instance_of(Spree::ShipmentHandler).to receive(:perform)
          shipment.update!(order)
        end
      end

      context 'when using a custom shipment handler' do
        before do
          Spree::ShipmentHandler::UPS = Class.new do
            def initialize(_shipment)
              true
            end

            def perform
              true
            end
          end
        end

        after do
          Spree::ShipmentHandler.send(:remove_const, :UPS)
        end

        it "calls the custom handler's 'perform' method" do
          shipment.state = 'pending'
          allow(shipment).to receive_messages determine_state: 'shipped'
          expect_any_instance_of(Spree::ShipmentHandler::UPS).to receive(:perform)
          shipment.update!(order)
        end
      end

      # Regression test for #4347
      context 'with adjustments' do
        before do
          shipment.adjustments << Spree::Adjustment.create(order: order, label: 'Label', amount: 5)
        end

        it 'transitions to shipped' do
          shipment.update_column(:state, 'ready')
          expect { shipment.ship! }.not_to raise_error
        end
      end
    end
  end

  context 'when order is completed' do
    after { Spree::Config.set track_inventory_levels: true }

    before do
      allow(order).to receive_messages completed?: true
      allow(order).to receive_messages canceled?: false
    end

    context 'with inventory tracking' do
      before { Spree::Config.set track_inventory_levels: true }

      it 'validates with inventory' do
        shipment.inventory_units = [create(:inventory_unit)]
        expect(shipment.valid?).to be true
      end
    end

    context 'without inventory tracking' do
      before { Spree::Config.set track_inventory_levels: false }

      it 'validates with no inventory' do
        expect(shipment.valid?).to be true
      end
    end
  end

  context '#cancel' do
    it 'cancels the shipment' do
      allow(shipment.order).to receive(:update_with_updater!)

      shipment.state = 'pending'
      expect(shipment).to receive(:after_cancel)
      shipment.cancel!
      expect(shipment.state).to eq 'canceled'
    end

    it 'restocks the items' do
      inventory_unit = mock_model(Spree::InventoryUnit, state: 'on_hand', line_item: line_item, variant: variant, quantity: 1)
      allow(shipment).to receive(:inventory_units).and_return([inventory_unit])
      shipment.stock_location = mock_model(Spree::StockLocation)
      expect(shipment.stock_location).to receive(:restock).with(variant, 1, shipment)
      shipment.after_cancel
    end

    context 'with backordered inventory units' do
      let(:order) { create(:order) }
      let(:variant) { create(:variant) }
      let(:other_order) { create(:order) }

      before do
        Spree::Cart::AddItem.call(order: order, variant: variant)
        order.create_proposed_shipments

        Spree::Cart::AddItem.call(order: other_order, variant: variant)
        other_order.create_proposed_shipments
      end

      it "doesn't fill backorders when restocking inventory units" do
        shipment = order.shipments.first
        expect(shipment.inventory_units.count).to eq 1
        expect(shipment.inventory_units.first).to be_backordered

        other_shipment = other_order.shipments.first
        expect(other_shipment.inventory_units.count).to eq 1
        expect(other_shipment.inventory_units.first).to be_backordered

        expect do
          shipment.cancel!
        end.not_to change { other_shipment.inventory_units.first.state }
      end
    end
  end

  context '#resume' do
    it 'transitions state to ready if the order is ready' do
      allow(shipment.order).to receive(:update_with_updater!)

      shipment.state = 'canceled'
      expect(shipment).to receive(:determine_state).and_return('ready')
      expect(shipment).to receive(:after_resume)
      shipment.resume!
      expect(shipment.state).to eq 'ready'
    end

    it 'transitions state to pending if the order is not ready' do
      allow(shipment.order).to receive(:update_with_updater!)

      shipment.state = 'canceled'
      expect(shipment).to receive(:determine_state).and_return('pending')
      expect(shipment).to receive(:after_resume)
      shipment.resume!
      # Shipment is pending because order is already paid
      expect(shipment.state).to eq 'pending'
    end

    it 'unstocks them items' do
      inventory_unit = mock_model(Spree::InventoryUnit, quantity: 1, line_item: line_item, variant: variant)
      allow(shipment).to receive(:inventory_units).and_return([inventory_unit])
      shipment.stock_location = mock_model(Spree::StockLocation)
      expect(shipment.stock_location).to receive(:unstock).with(variant, 1, shipment)
      shipment.after_resume
    end
  end

  context '#ship' do
    context 'when the shipment is canceled' do
      let(:shipment_with_inventory_units) { create(:shipment, order: create(:order_with_line_items), state: 'canceled') }
      let(:subject) { shipment_with_inventory_units.ship! }

      before do
        allow(order).to receive(:update_with_updater!)
        allow(shipment_with_inventory_units).to receive_messages(require_inventory: false, update_order: true)
      end

      it 'unstocks them items' do
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:send_shipped_email)

        expect(shipment_with_inventory_units.stock_location).to receive(:unstock)
        subject
      end
    end

    ['ready', 'canceled'].each do |state|
      context "from #{state}" do
        before do
          allow(order).to receive(:update_with_updater!)
          allow(shipment).to receive_messages(require_inventory: false, update_order: true, state: state)
        end

        it 'updates shipped_at timestamp' do
          allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)
          allow_any_instance_of(Spree::ShipmentHandler).to receive(:send_shipped_email)

          shipment.ship!
          expect(shipment.shipped_at).not_to be_nil
          # Ensure value is persisted
          shipment.reload
          expect(shipment.shipped_at).not_to be_nil
        end

        it 'sends a shipment email' do
          mail_message = double 'Mail::Message'
          shipment_id = nil
          expect(Spree::ShipmentMailer).to receive(:shipped_email) { |*args|
            shipment_id = args[0]
            mail_message
          }
          expect(mail_message).to receive :deliver_later
          allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)

          shipment.ship!
          expect(shipment_id).to eq(shipment.id)
        end

        it 'finalizes adjustments' do
          allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)
          allow_any_instance_of(Spree::ShipmentHandler).to receive(:send_shipped_email)

          expect(shipment.adjustments).to all(receive(:finalize!))
          shipment.ship!
        end
      end
    end
  end

  context '#ready' do
    context 'with Config.auto_capture_on_dispatch == false' do
      # Regression test for #2040
      it 'cannot ready a shipment for an order if the order is unpaid' do
        allow(order).to receive_messages(paid?: false)
        assert !shipment.can_ready?
      end
    end

    context 'with Config.auto_capture_on_dispatch == true' do
      before do
        Spree::Config[:auto_capture_on_dispatch] = true
        @order = create :completed_order_with_pending_payment
        @shipment = @order.shipments.first
        @shipment.cost = @order.ship_total
      end

      it 'shipments ready for an order if the order is unpaid' do
        expect(@shipment.ready?).to be true
      end

      it 'tells the order to process payment in #after_ship' do
        expect(@shipment).to receive(:process_order_payments)
        @shipment.ship!
      end

      context 'order has pending payments' do
        let(:payment) do
          payment = @order.payments.first
          payment.update_attribute :state, 'pending'
          payment
        end

        before do
          calculator = @shipment.shipping_method.calculator
          calculator.set_preference(:amount, @shipment.cost)
          calculator.save!
        end

        it 'can fully capture an authorized payment' do
          payment.update_attribute(:amount, @order.total)

          expect(payment.amount).to eq payment.uncaptured_amount
          @shipment.ship!
          expect(payment.reload.uncaptured_amount.to_f).to eq 0
        end

        it 'can partially capture an authorized payment' do
          payment.update_attribute(:amount, @order.total + 50)

          expect(payment.amount).to eq payment.uncaptured_amount
          @shipment.ship!
          expect(payment.captured_amount).to eq @order.total
          expect(payment.captured_amount).to eq payment.amount - 50
          expect(payment.order.payments.pending.first.amount).to eq 50
        end
      end
    end
  end

  context 'updates cost when selected shipping rate is present' do
    let(:shipment) { create(:shipment) }

    before { allow(shipment).to receive_message_chain :selected_shipping_rate, cost: 5 }

    it 'updates shipment totals' do
      shipment.update_amounts
      expect(shipment.reload.cost).to eq(5)
    end

    it 'factors in additional adjustments to adjustment total' do
      shipment.adjustments.create!(
        order: order,
        label: 'Additional',
        amount: 5,
        included: false,
        state: 'closed'
      )
      shipment.update_amounts
      expect(shipment.reload.adjustment_total).to eq(5)
    end

    it 'does not factor in included adjustments to adjustment total' do
      shipment.adjustments.create!(
        order: order,
        label: 'Included',
        amount: 5,
        included: true,
        state: 'closed'
      )
      shipment.update_amounts
      expect(shipment.reload.adjustment_total).to eq(0)
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
      shipment.update_attributes_and_order selected_shipping_rate_id: shipping_rate.id
    end

    it 'updates everything around order shipment total and state' do
      expect(shipment.cost.to_f).to eq 10
      expect(shipment.state).to eq 'pending'
      expect(shipment.order.total.to_f).to eq 110
      expect(shipment.order.payment_state).to eq 'balance_due'
    end
  end

  context 'after_save' do
    context 'line item changes' do
      before do
        shipment.cost = shipment.cost + 10
      end

      it 'triggers adjustment total recalculation' do
        expect(shipment).to receive(:recalculate_adjustments)
        shipment.save
      end

      it 'does not trigger adjustment recalculation if shipment has shipped' do
        shipment.state = 'shipped'
        expect(shipment).not_to receive(:recalculate_adjustments)
        shipment.save
      end
    end

    context 'line item does not change' do
      it 'does not trigger adjustment total recalculation' do
        expect(shipment).not_to receive(:recalculate_adjustments)
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

  context '#tracking_url' do
    it 'uses shipping method to determine url' do
      expect(shipping_method).to receive(:build_tracking_url).with('1Z12345').and_return(:some_url)
      shipment.tracking = '1Z12345'

      expect(shipment.tracking_url).to eq(:some_url)
    end
  end

  context '#transfer_to_location' do
    # Order with 2 line items in order to be able to split one shipment into 2
    let(:order) { create(:completed_order_with_totals, line_items_count: 2) }
    let(:stock_location) { create(:stock_location) }
    let(:variant) { order.line_items.first.variant }

    before do
      shipping_method = order.shipments.first.shipping_method
      shipping_method.calculator.preferences[:amount] = order.shipments.first.cost
      shipping_method.calculator.save!
    end

    it 'creates new shipment for same order' do
      shipment = order.shipments.first

      expect { shipment.transfer_to_location(variant, 1, stock_location) }.
        to change { order.reload.shipments.size }.from(1).to(2)
    end

    it 'sets the given stock location for new shipment' do
      shipment = order.shipments.first
      shipment.transfer_to_location(variant, 1, stock_location)

      new_shipment = order.reload.shipments.last

      expect(new_shipment.stock_location).not_to eq(shipment.stock_location)
    end

    it 'sets proper costs for new shipment' do
      shipment = order.shipments.first
      shipment.transfer_to_location(variant, 1, shipment.stock_location)

      new_shipment = order.reload.shipments.last
      # Cost must be the same since both come from the same stock location
      expect(new_shipment.cost).to eq(shipment.cost)
    end

    it 'updates `order.shipment_total` to the sum of shipments cost' do
      shipment = order.shipments.first
      shipment.transfer_to_location(variant, 1, shipment.stock_location)

      order.reload
      expect(order.shipment_total).to eq(order.shipments.sum(&:cost))
    end
  end

  context 'set up new inventory units' do
    # let(:line_item) { double(
    let(:variant) { double('Variant', id: 9) }

    let(:inventory_units) { double }

    let(:params) do
      { variant_id: variant.id, state: 'on_hand', order_id: order.id, line_item_id: line_item.id, quantity: 1 }
    end

    before { allow(shipment).to receive_messages inventory_units: inventory_units }

    it 'associates variant and order' do
      expect(inventory_units).to receive(:create).with(params)
      shipment.set_up_inventory('on_hand', variant, order, line_item)
    end
  end

  # Regression test for #3349
  context '#destroy' do
    it 'destroys linked shipping_rates' do
      reflection = Spree::Shipment.reflect_on_association(:shipping_rates)
      expect(reflection.options[:dependent]).to be(:delete_all)
    end
  end

  # Regression test for #4072 (kinda)
  # The need for this was discovered in the research for #4702
  context 'state changes' do
    before do
      # Must be stubbed so transition can succeed
      allow(order).to receive_messages paid?: true
    end

    it 'are logged to the database' do
      expect(shipment.state_changes).to be_empty
      expect(shipment.ready!).to be true
      expect(shipment.state_changes.count).to eq(1)
      state_change = shipment.state_changes.first
      expect(state_change.previous_state).to eq('pending')
      expect(state_change.next_state).to eq('ready')
    end
  end
end
