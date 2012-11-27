require 'spec_helper'

describe Spree::Shipment do
  before(:each) do
    reset_spree_preferences
  end

  let(:order) { mock_model Spree::Order, :backordered? => false, :complete? => true, :currency => "USD" }
  let(:shipping_method) { mock_model Spree::ShippingMethod, :calculator => mock('calculator') }
  let(:shipment) do
    shipment = Spree::Shipment.new :order => order, :shipping_method => shipping_method
    shipment.state = 'pending'
    shipment
  end

  let(:charge) { mock_model Spree::Adjustment, :amount => 10, :source => shipment }

  context "#cost" do
    it "should return the amount of any shipping charges that it originated" do
      shipment.stub_chain :adjustment, :amount => 10
      shipment.cost.should == 10
    end

    it "should return 0 if there are no relevant shipping adjustments" do
      shipment.cost.should == 0
    end
  end

  context "#update!" do

    shared_examples_for "immutable once shipped" do
      it "should remain in shipped state once shipped" do
        shipment.state = "shipped"
        shipment.should_receive(:update_column).with("state", "shipped")
        shipment.update!(order)
      end
    end

    shared_examples_for "pending if backordered" do
      it "should have a state of pending if backordered" do
        shipment.stub(:inventory_units => [mock_model(Spree::InventoryUnit, :backordered? => true)] )
        shipment.should_receive(:update_column).with("state", "pending")
        shipment.update!(order)
      end
    end

    context "when order is incomplete" do
      before { order.stub :complete? => false }
      it "should result in a 'pending' state" do
        shipment.should_receive(:update_column).with("state", "pending")
        shipment.update!(order)
      end
    end

    context "when order is paid" do
      before { order.stub :paid? => true }
      it "should result in a 'ready' state" do
        shipment.should_receive(:update_column).with("state", "ready")
        shipment.update!(order)
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end

    context "when order has balance due" do
      before { order.stub :paid? => false }
      it "should result in a 'pending' state" do
        shipment.state = 'ready'
        shipment.should_receive(:update_column).with("state", "pending")
        shipment.update!(order)
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end

    context "when order has a credit owed" do
      before { order.stub :payment_state => 'credit_owed', :paid? => true }
      it "should result in a 'ready' state" do
        shipment.state = 'pending'
        shipment.should_receive(:update_column).with("state", "ready")
        shipment.update!(order)
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end

    context "when shipment state changes to shipped" do
      it "should call after_ship" do
        shipment.state = "pending"
        shipment.should_receive :after_ship
        shipment.stub :determine_state => 'shipped'
        shipment.should_receive(:update_column).with("state", "shipped")
        shipment.update!(order)
      end
    end
  end

  context "when track_inventory is false" do

    before { Spree::Config.set :track_inventory_levels => false }
    after { Spree::Config.set :track_inventory_levels => true }

    it "should not use the line items from order when track_inventory_levels is false" do
      line_items = [mock_model(Spree::LineItem)]
      order.stub :complete? => true
      order.stub :line_items => line_items
      shipment.line_items.should == line_items
    end

  end

  context "when order is completed" do
    after { Spree::Config.set :track_inventory_levels => true }

    before do
      order.stub :completed? => true
      order.stub :canceled? => false
    end


    context "with inventory tracking" do
      before { Spree::Config.set :track_inventory_levels => true }

      it "should not validate without inventory" do
        shipment.valid?.should be_false
      end

      it "should validate with inventory" do
        shipment.inventory_units = [create(:inventory_unit)]
        shipment.valid?.should be_true
      end

    end

    context "without inventory tracking" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should validate with no inventory" do
        shipment.valid?.should be_true
      end
    end

  end

  context "#ship" do
    before do
      order.stub(:update!)
      shipment.stub(:require_inventory => false, :update_order => true, :state => 'ready')
      shipping_method.stub(:create_adjustment)
    end

    it "should update shipped_at timestamp" do
      shipment.stub(:send_shipped_email)
      shipment.ship!
      shipment.shipped_at.should_not be_nil
      # Ensure value is persisted
      shipment.reload
      shipment.shipped_at.should_not be_nil
    end

    it "should send a shipment email" do
      mail_message = mock "Mail::Message"
      Spree::ShipmentMailer.should_receive(:shipped_email).with(shipment).and_return mail_message
      mail_message.should_receive :deliver
      shipment.ship!
    end
  end

  context "#ready" do
    # Regression test for #2040
    it "cannot ready a shipment for an order if the order is unpaid" do
      order.stub(:paid? => false)
      assert !shipment.can_ready?
    end
  end

  context "ensure_correct_adjustment" do
    before { shipment.stub(:reload) }

    it "should create adjustment when not present" do
      shipping_method.should_receive(:create_adjustment).with(I18n.t(:shipping), order, shipment, true)
      shipment.send(:ensure_correct_adjustment)
    end

    it "should update originator when adjustment is present" do
      shipment.stub_chain(:adjustment, :originator)
      shipment.adjustment.should_receive(:originator=).with(shipping_method)
      shipment.adjustment.should_receive(:save)
      shipment.send(:ensure_correct_adjustment)
    end
  end

  context "update_order" do
    it "should update order" do
      order.should_receive(:update!)
      shipment.send(:update_order)
    end
  end

  context "after_save" do
    it "should run correct callbacks" do
      shipment.should_receive(:ensure_correct_adjustment)
      shipment.should_receive(:update_order)
      shipment.run_callbacks(:save, :after)
    end
  end

  context "currency" do
    it "returns the order currency" do
      shipment.currency.should == order.currency
    end
  end

  context "display_cost" do
    it "retuns a Spree::Money" do
      shipment.stub(:cost) { 21.22 }
      shipment.display_cost.should == Spree::Money.new(21.22)
    end
  end
end
