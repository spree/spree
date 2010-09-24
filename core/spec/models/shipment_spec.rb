require 'spec_helper'

describe Shipment do
  let(:order) { mock_model Order, :backordered? => false }
  let(:shipment) { Shipment.new :order => order, :state => 'pending' }

  let(:charge) { mock_model Adjustment, :amount => 10, :source => shipment }

  context "#cost" do
    it "should return the amount of any shipping charges that it originated" do
      shipment.stub_chain :order, :adjustments, :shipping => [charge]
      shipment.cost.should == 10
    end

    it "should return 0 if there are no relevant shipping adjustments" do
      shipment.stub_chain :order, :adjustments, :shipping => []
      shipment.cost.should == 0
    end
  end

  context "#update!" do

    shared_examples_for "immutable once shipped" do
      it "should remain in shipped state once shipped" do
        shipment.state = "shipped"
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "shipped")
        shipment.update!(order)
      end
    end

    shared_examples_for "pending if backordered" do
      it "should have a state of pending if backordered" do
        order.stub :backordered? => true
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "pending")
        shipment.update!(order)
      end
    end

    context "when order is paid" do
      before { order.stub :payment_state => 'paid' }
      it "should result in a 'ready' state" do
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "ready")
        shipment.update!(order)
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end

    context "when order has balance due" do
      before { order.stub :payment_state => 'balance_due' }
      it "should result in a 'pending' state" do
        shipment.state = 'ready'
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "pending")
        shipment.update!(order)
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end

    context "when order has a credit owed" do
      before { order.stub :payment_state => 'credit_owed' }
      it "should result in a 'ready' state" do
        shipment.state = 'pending'
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "ready")
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
        shipment.update!(order)
      end
    end
  end

  context "when track_inventory is false" do

    before { Spree::Config.set :track_inventory_levels => false }
    after { Spree::Config.set :track_inventory_levels => true }

    it "should not use the line items from order when track_inventory_levels is false" do
      line_items = [mock_model LineItem]
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
        shipment.inventory_units = [mock_model(InventoryUnit)]
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
      shipment.state = 'ready'
      shipment.stub :require_inventory => false
    end

    it "should send a shipment email" do
      mail_message = mock "Mail::Message"
      ShipmentMailer.should_receive(:shipped_email).with(shipment).and_return mail_message
      mail_message.should_receive :deliver
      shipment.ship!
    end

  end
end