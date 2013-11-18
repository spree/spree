require 'spec_helper'

module Spree
  describe OrderUpdater do
    let(:order) { Spree::Order.create }
    let(:updater) { Spree::OrderUpdater.new(order) }

    context "order totals" do
      before do 
        2.times do
          create(:line_item, :order => order, price: 10)
        end
      end

      it "updates payment totals" do
        order.stub_chain(:payments, :completed, :sum).and_return(10)

        updater.update_totals
        order.payment_total.should == 10
      end

      it "update item total" do
        updater.update_item_total
        order.item_total.should == 20
      end

      it "update shipment total" do
        create(:shipment, :order => order, :cost => 10)
        updater.update_shipment_total
        order.shipment_total.should == 10
      end

      it "update order adjustments" do
        # A line item will not have both additional and included tax,
        # so please just humour me for now.
        order.line_items.first.update_columns({
          :adjustment_total => 10.05,
          :additional_tax_total => 0.05,
          :included_tax_total => 0.05,
        })
        updater.update_adjustment_total
        order.adjustment_total.should == 10.05
        order.additional_tax_total.should == 0.05
        order.included_tax_total.should == 0.05
      end
    end

    context "updating shipment state" do
      before do
        order.stub :backordered? => false
        order.stub_chain(:shipments, :shipped, :count).and_return(0)
        order.stub_chain(:shipments, :ready, :count).and_return(0)
        order.stub_chain(:shipments, :pending, :count).and_return(0)
      end

      it "is backordered" do
        order.stub :backordered? => true
        updater.update_shipment_state

        order.shipment_state.should == 'backorder'
      end

      it "is nil" do
        order.stub_chain(:shipments, :states).and_return([])
        order.stub_chain(:shipments, :count).and_return(0)

        updater.update_shipment_state
        order.shipment_state.should be_nil
      end


      ["shipped", "ready", "pending"].each do |state|
        it "is #{state}" do
          order.stub_chain(:shipments, :states).and_return([state])
          updater.update_shipment_state
          order.shipment_state.should == state.to_s
        end
      end

      it "is partial" do
        order.stub_chain(:shipments, :states).and_return(["pending", "ready"])
        updater.update_shipment_state
        order.shipment_state.should == 'partial'
      end
    end

    context "updating payment state" do
      it "is failed if last payment failed" do
        order.stub_chain(:payments, :last, :state).and_return('failed')

        updater.update_payment_state
        order.payment_state.should == 'failed'
      end

      it "is balance due with no line items" do
        order.stub_chain(:line_items, :empty?).and_return(true)

        updater.update_payment_state
        order.payment_state.should == 'balance_due'
      end

      it "is credit owed if payment is above total" do
        order.stub_chain(:line_items, :empty?).and_return(false)
        order.stub :payment_total => 31
        order.stub :total => 30

        updater.update_payment_state
        order.payment_state.should == 'credit_owed'
      end

      it "is paid if order is paid in full" do
        order.stub_chain(:line_items, :empty?).and_return(false)
        order.stub :payment_total => 30
        order.stub :total => 30

        updater.update_payment_state
        order.payment_state.should == 'paid'
      end
    end

    it "state change" do
      order.shipment_state = 'shipped'
      state_changes = double
      order.stub :state_changes => state_changes
      state_changes.should_receive(:create).with(
        :previous_state => nil,
        :next_state => 'shipped',
        :name => 'shipment',
        :user_id => nil
      )

      order.state_changed('shipment')
    end

    context "completed order" do
      before { order.stub completed?: true }

      it "updates payment state" do
        expect(updater).to receive(:update_payment_state)
        updater.update
      end

      it "updates shipment state" do
        expect(updater).to receive(:update_shipment_state)
        updater.update
      end

      it "updates each shipment" do
        shipment = stub_model(Spree::Shipment)
        shipments = [shipment]
        order.stub :shipments => shipments
        shipments.stub :states => []
        shipments.stub :ready => []
        shipments.stub :pending => []
        shipments.stub :shipped => []

        shipment.should_receive(:update!).with(order)
        updater.update_shipments
      end
    end

    context "incompleted order" do
      before { order.stub completed?: false }

      it "doesnt update payment state" do
        expect(updater).not_to receive(:update_payment_state)
        updater.update
      end

      it "doesnt update shipment state" do
        expect(updater).not_to receive(:update_shipment_state)
        updater.update
      end

      it "doesnt update each shipment" do
        shipment = stub_model(Spree::Shipment)
        shipments = [shipment]
        order.stub :shipments => shipments
        shipments.stub :states => []
        shipments.stub :ready => []
        shipments.stub :pending => []
        shipments.stub :shipped => []

        updater.stub(:update_totals) # Otherwise this gets called and causes a scene
        expect(updater).not_to receive(:update_shipments).with(order)
        updater.update
      end
    end
  end
end
