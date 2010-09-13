require 'spec_helper'

describe Shipment do
  let(:shipment) { Shipment.new }
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
    let(:order) { mock_model Order, :backordered? => false }
    let(:shipment) { Shipment.new :order => order, :state => 'pending' }

    shared_examples_for "immutable once shipped" do
      it "should remain in shipped state once shipped" do
        shipment.state = "shipped"
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "shipped")
        shipment.update!
      end
    end

    shared_examples_for "pending if backordered" do
      it "should have a state of pending if backordered" do
        order.stub :backordered? => true
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "pending")
        shipment.update!
      end
    end

    context "when order is paid" do
      before { order.stub :payment_state => 'paid' }
      it "should result in a 'ready' state" do
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "ready")
        shipment.update!
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end
    context "when order has balance due" do
      before { order.stub :payment_state => 'balance_due' }
      it "should result in a 'pending' state" do
        shipment.state = 'ready'
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "pending")
        shipment.update!
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end
    context "when order has a credit owed" do
      before { order.stub :payment_state => 'credit_owed' }
      it "should result in a 'ready' state" do
        shipment.state = 'pending'
        shipment.should_receive(:update_attribute_without_callbacks).with("state", "ready")
        shipment.update!
      end
      it_should_behave_like "immutable once shipped"
      it_should_behave_like "pending if backordered"
    end
  end
end