require_relative '../../app/models/spree/order_updater.rb'
require 'active_support/core_ext/enumerable'

class FakeOrder
  attr_accessor :payment_total, :item_total, :adjustment_total, :total,
                :line_items, :payment_state, :shipment_state, :changed_attributes

  def initialize
    @line_items = []
    @changed_attributes = {}
  end
end

describe Spree::OrderUpdater do
  let(:order) do
    FakeOrder.new
  end

  let(:updater) { Spree::OrderUpdater.new(order) }

  it "updates an order's totals" do
    order.stub :completed_payment_total => 1
    order.stub :line_item_total => 2
    order.stub :eligible_adjustments_total => 3
    updater.update_totals
    order.payment_total.should == 1
    order.total.should == 5
  end

  context "#update_payment_state" do
    context "if there are no line items" do
      before { order.stub :line_items => [] }

      context "if last payment did not fail" do
        before { order.stub :last_payment_failed? => false }
        it "is marked as balance_due" do
          updater.update_payment_state
          order.payment_state.should == 'balance_due'
        end
      end

      context "if last payment failed" do
        before { order.stub :last_payment_failed? => true }
        it "is marked as failed" do
          updater.update_payment_state
          order.payment_state.should == 'failed'
        end
      end
    end

    context "if there are line items" do
      before { order.stub :line_items => [stub] }
      context "if payment is over order total" do
        before do
          order.stub :last_payment_failed? => false
          order.stub :payment_total => 100
          order.stub :total => 99
        end

        it "is marked as credit_owed" do
          updater.update_payment_state
          order.payment_state.should == 'credit_owed'
        end
      end

      context "if order is paid" do
        before do
          order.stub :last_payment_failed? => false
          order.stub :payment_total => 100
          order.stub :total => 100
        end

        it "is marked as paid" do
          updater.update_payment_state
          order.payment_state.should == 'paid'
        end

      end
    end
  end

  it "updates shipments" do
    shipment = stub
    order.stub :shipments => [shipment]
    shipment.should_receive(:update!).with(order)
    updater.update_shipments
  end

  context "update_shipment_state" do
    let(:shipment) { stub(:shipment) }

    before do
      order.stub :shipments => []
      order.stub_chain :shipments, :shipped => []
      order.stub_chain :shipments, :ready   => []
      order.stub_chain :shipments, :pending => []
      order.stub :backordered? => false
    end

    context "when there are no shipments" do
      it "shipment state is nil" do
        order.shipment_state.should be_nil
        updater.update_shipment_state
      end
    end

    context "when all shipments are shipped" do
      before do
        order.stub :shipments => [shipment]
        order.stub_chain :shipments, :shipped => order.shipments
      end

      it "shipment state is shipped" do
        updater.update_shipment_state
        order.shipment_state.should == "shipped"
      end
    end

    context "when all shipments are ready" do
      before do
        order.stub :shipments => [shipment]
        order.stub_chain :shipments, :shipped => []
        order.stub_chain :shipments, :ready => order.shipments
      end

      it "shipment state is ready" do
        updater.update_shipment_state
        order.shipment_state.should == "ready"
      end
    end

    context "when all shipments are pending" do
      before do
        order.stub :shipments => [shipment]
        order.stub_chain :shipments, :shipped => []
        order.stub_chain :shipments, :ready => []
        order.stub_chain :shipments, :pending => order.shipments
      end

      it "shipment state is pending" do
        updater.update_shipment_state
        order.shipment_state.should == "pending"
      end
    end

    context "when shipments are in different states" do
      before do
        order.stub_chain :shipments => [shipment]
        order.stub_chain :shipments, :shipped => []
        order.stub_chain :shipments, :ready => []
        order.stub_chain :shipments, :pending => []
      end

      it "shipment state is partial" do
        updater.update_shipment_state
        order.shipment_state.should == "partial"
      end
    end
  end

  it "updates adjustments" do
    adjustment = stub(:adjustment)
    order.stub_chain :adjustments, :reload => [adjustment]
    adjustment.should_receive(:update!).with(order)
    updater.update_adjustments
  end

  context "ensures correct payment total" do
    let!(:payment) { stub(:payment) }
    before do
      order.stub :payment => payment
      payment.stub :amount => 10
      order.total = 3
    end

    it "if payment is in checkout state" do
      payment.stub :checkout? => true
      payment.should_receive(:update_column).with(:amount, 3)
      updater.ensure_correct_payment_total
    end

    it "if order total equals payment amount" do
      payment.stub :checkout? => true
      order.total = 10
      payment.should_not_receive(:update_column)
      updater.ensure_correct_payment_total
    end

    it "if payment is not in checkout state" do
      payment.stub :checkout? => false
      payment.should_not_receive(:update_column)
      updater.ensure_correct_payment_total
    end

  end
end
