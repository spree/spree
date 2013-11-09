require 'spec_helper'
require 'benchmark'

describe Spree::Shipment do
  let(:order) { mock_model Spree::Order, backordered?: false,
                                         canceled?: false,
                                         can_ship?: true,
                                         currency: 'USD' }
  let(:shipping_method) { create(:shipping_method, name: "UPS") }
  let(:shipment) do
    shipment = Spree::Shipment.new order: order
    shipment.stub(shipping_method: shipping_method)
    shipment.state = 'pending'
    shipment.cost = 1
    shipment.save
    shipment
  end

  let(:variant) { mock_model(Spree::Variant) }

  it 'is backordered if one if its inventory_units is backordered' do
    shipment.stub(inventory_units: [
      mock_model(Spree::InventoryUnit, backordered?: false),
      mock_model(Spree::InventoryUnit, backordered?: true)
    ])
    shipment.should be_backordered
  end

  context "display_amount" do
    it "retuns a Spree::Money" do
      shipment.stub(:cost) { 21.22 }
      shipment.display_amount.should == Spree::Money.new(21.22)
    end
  end

  context "display_item_cost" do
    it "retuns a Spree::Money" do
      shipment.stub(:item_cost) { 21.22 }
      shipment.display_item_cost.should == Spree::Money.new(21.22)
    end
  end

  it "#item_cost" do
    shipment = create(:shipment, order: create(:order_with_totals))
    shipment.item_cost.should eql(10.0)
  end

  it "#discounted_cost" do
    shipment = create(:shipment)
    shipment.cost = 10
    shipment.promo_total = -1
    shipment.discounted_cost.should == 9
  end

  context "manifest" do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { order.contents.add variant }
    let!(:shipment) { order.create_proposed_shipments.first }

    it "returns variant expected" do
      expect(shipment.manifest.first.variant).to eq variant
    end

    context "variant was removed" do
      before { variant.product.destroy }

      it "still returns variant expected" do
        expect(shipment.manifest.first.variant).to eq variant
      end
    end
  end

  context 'shipping_rates' do
    let(:shipment) { create(:shipment) }
    let(:shipping_method1) { create(:shipping_method) }
    let(:shipping_method2) { create(:shipping_method) }
    let(:shipping_rates) { [
      Spree::ShippingRate.new(shipping_method: shipping_method1, cost: 10.00, selected: true),
      Spree::ShippingRate.new(shipping_method: shipping_method2, cost: 20.00)
    ] }

    it 'returns shipping_method from selected shipping_rate' do
      shipment.shipping_rates.delete_all
      shipment.shipping_rates.create shipping_method: shipping_method1, cost: 10.00, selected: true
      shipment.shipping_method.should eq shipping_method1
    end

    context 'refresh_rates' do
      let(:mock_estimator) { double('estimator', shipping_rates: shipping_rates) }
      before { shipment.stub(:can_get_rates?){ true } }

      it 'should request new rates, and maintain shipping_method selection' do
        Spree::Stock::Estimator.should_receive(:new).with(shipment.order).and_return(mock_estimator)
        shipment.stub(shipping_method: shipping_method2)

        shipment.refresh_rates.should == shipping_rates
        shipment.reload.selected_shipping_rate.shipping_method_id.should == shipping_method2.id
      end

      it 'should handle no shipping_method selection' do
        Spree::Stock::Estimator.should_receive(:new).with(shipment.order).and_return(mock_estimator)
        shipment.stub(shipping_method: nil)
        shipment.refresh_rates.should == shipping_rates
        shipment.reload.selected_shipping_rate.should_not be_nil
      end

      it 'should not refresh if shipment is shipped' do
        Spree::Stock::Estimator.should_not_receive(:new)
        shipment.shipping_rates.delete_all
        shipment.stub(shipped?: true)
        shipment.refresh_rates.should == []
      end

      it "can't get rates without a shipping address" do
        shipment.order(ship_address: nil)
        expect(shipment.refresh_rates).to eq([])
      end

      context 'to_package' do
        it 'should use symbols for states when adding contents to package' do
          shipment.stub_chain(:inventory_units, includes: [ build(:inventory_unit, variant: variant, state: 'on_hand'),
                                                            build(:inventory_unit, variant: variant, state: 'backordered') ] )
          package = shipment.to_package
          package.on_hand.count.should eq 1
          package.backordered.count.should eq 1
        end
      end
    end
  end

  context "#update!" do
    shared_examples_for "immutable once shipped" do
      it "should remain in shipped state once shipped" do
        shipment.state = 'shipped'
        shipment.should_receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    shared_examples_for "pending if backordered" do
      it "should have a state of pending if backordered" do
        shipment.stub(inventory_units: [mock_model(Spree::InventoryUnit, backordered?: true)])
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context "when order cannot ship" do
      before { order.stub can_ship?: false }
      it "should result in a 'pending' state" do
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end

    context "when order is paid" do
      before { order.stub paid?: true }
      it "should result in a 'ready' state" do
        shipment.should_receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when order has balance due" do
      before { order.stub paid?: false }
      it "should result in a 'pending' state" do
        shipment.state = 'ready'
        shipment.should_receive(:update_columns).with(state: 'pending', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when order has a credit owed" do
      before { order.stub payment_state: 'credit_owed', paid?: true }
      it "should result in a 'ready' state" do
        shipment.state = 'pending'
        shipment.should_receive(:update_columns).with(state: 'ready', updated_at: kind_of(Time))
        shipment.update!(order)
      end
      it_should_behave_like 'immutable once shipped'
      it_should_behave_like 'pending if backordered'
    end

    context "when shipment state changes to shipped" do
      it "should call after_ship" do
        shipment.state = 'pending'
        shipment.should_receive :after_ship
        shipment.stub determine_state: 'shipped'
        shipment.should_receive(:update_columns).with(state: 'shipped', updated_at: kind_of(Time))
        shipment.update!(order)
      end
    end
  end

  context "when track_inventory is false" do
    before { Spree::Config.set track_inventory_levels: false }
    after { Spree::Config.set track_inventory_levels: true }

    it "should not use the line items from order when track_inventory_levels is false" do
      line_items = [mock_model(Spree::LineItem)]
      order.stub complete?: true
      order.stub line_items: line_items
      shipment.line_items.should == line_items
    end
  end

  context "when order is completed" do
    after { Spree::Config.set track_inventory_levels: true }

    before do
      order.stub completed?: true
      order.stub canceled?: false
    end

    context "with inventory tracking" do
      before { Spree::Config.set track_inventory_levels: true }

      it "should validate with inventory" do
        shipment.inventory_units = [create(:inventory_unit)]
        shipment.valid?.should be_true
      end
    end

    context "without inventory tracking" do
      before { Spree::Config.set track_inventory_levels: false }

      it "should validate with no inventory" do
        shipment.valid?.should be_true
      end
    end
  end

  context "#cancel" do
    it 'cancels the shipment' do
      shipment.order.stub(:update!)

      shipment.state = 'pending'
      shipment.should_receive(:after_cancel)
      shipment.cancel!
      shipment.state.should eq 'canceled'
    end

    it 'restocks the items' do
      shipment.stub_chain(inventory_units: [mock_model(Spree::InventoryUnit, variant: variant)])
      shipment.stock_location = mock_model(Spree::StockLocation)
      shipment.stock_location.should_receive(:restock).with(variant, 1, shipment)
      shipment.after_cancel
    end
  end

  context "#resume" do
    it 'will determine new state based on order' do
      shipment.order.stub(:update!)

      shipment.state = 'canceled'
      shipment.should_receive(:determine_state).and_return(:ready)
      shipment.should_receive(:after_resume)
      shipment.resume!
      shipment.state.should eq 'ready'
    end

    it 'unstocks them items' do
      shipment.stub_chain(inventory_units: [mock_model(Spree::InventoryUnit, variant: variant)])
      shipment.stock_location = mock_model(Spree::StockLocation)
      shipment.stock_location.should_receive(:unstock).with(variant, 1, shipment)
      shipment.after_resume
    end

    it 'will determine new state based on order' do
      shipment.order.stub(:update!)

      shipment.state = 'canceled'
      shipment.should_receive(:determine_state).twice.and_return('ready')
      shipment.should_receive(:after_resume)
      shipment.resume!
      # Shipment is pending because order is already paid
      shipment.state.should eq 'pending'
    end
  end

  context "#ship" do
    before do
      order.stub(:update!)
      shipment.stub(require_inventory: false, update_order: true, state: 'ready')
    end

    it "should update shipped_at timestamp" do
      shipment.stub(:send_shipped_email)
      shipment.stub(:update_order_shipment_state)
      shipment.ship!
      shipment.shipped_at.should_not be_nil
      # Ensure value is persisted
      shipment.reload
      shipment.shipped_at.should_not be_nil
    end

    it "should send a shipment email" do
      mail_message = double 'Mail::Message'
      shipment_id = nil
      Spree::ShipmentMailer.should_receive(:shipped_email) { |*args|
        shipment_id = args[0]
        mail_message
      }
      mail_message.should_receive :deliver
      shipment.stub(:update_order_shipment_state)
      shipment.ship!
      shipment_id.should == shipment.id
    end

    it "finalizes adjustments" do
      shipment.stub(:send_shipped_email)
      shipment.stub(:update_order_shipment_state)
      shipment.adjustments.each do |adjustment|
        expect(adjustment).to receive(:finalize!)
      end
      shipment.ship!
    end
  end

  context "#ready" do
    # Regression test for #2040
    it "cannot ready a shipment for an order if the order is unpaid" do
      order.stub(paid?: false)
      assert !shipment.can_ready?
    end
  end

  context "create adjustments" do
    let(:shipment) { create(:shipment) }

    before { shipment.stub_chain :selected_shipping_rate, cost: 5 }

    it "updates shipment totals" do
      shipment.update_amounts
      shipment.reload.cost.should == 5
    end
  end

  context "after_save" do
    context "line item changes" do
      before do
        shipment.cost = shipment.cost + 10
      end

      it "triggers adjustment total recalculation" do
        shipment.should_receive(:recalculate_adjustments)
        shipment.save
      end

      it "does not trigger adjustment recalculation if shipment has shipped" do
        shipment.state = 'shipped'
        shipment.should_not_receive(:recalculate_adjustments)
        shipment.save
      end
    end

    context "line item does not change" do
      it "does not trigger adjustment total recalculation" do
        shipment.should_not_receive(:recalculate_adjustments)
        shipment.save
      end
    end
  end

  context "currency" do
    it "returns the order currency" do
      shipment.currency.should == order.currency
    end
  end

  context "nil costs" do
    it "sets cost to 0" do
      shipment = Spree::Shipment.new
      shipment.valid?
      expect(shipment.cost).to eq 0
    end
  end

  context "#tracking_url" do
    it "uses shipping method to determine url" do
      shipping_method.should_receive(:build_tracking_url).with('1Z12345').and_return(:some_url)
      shipment.tracking = '1Z12345'

      shipment.tracking_url.should == :some_url
    end
  end

  context "set up new inventory units" do
    let(:variant) { double("Variant", id: 9) }
    let(:inventory_units) { double }
    let(:params) do
      { variant_id: variant.id, state: 'on_hand', order_id: order.id }
    end

    before { shipment.stub inventory_units: inventory_units }

    it "associates variant and order" do
      expect(inventory_units).to receive(:create).with(params)
      unit = shipment.set_up_inventory('on_hand', variant, order)
    end
  end

  # Regression test for #3349
  context "#destroy" do
    it "destroys linked shipping_rates" do
      reflection = Spree::Shipment.reflect_on_association(:shipping_rates)
      reflection.options[:dependent] = :destroy
    end
  end
end
