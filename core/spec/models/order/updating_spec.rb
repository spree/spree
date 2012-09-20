require 'spec_helper'

describe Spree::Order do
  let(:order) { stub_model(Spree::Order) }

  context "#update!" do
    let(:line_items) { [mock_model(Spree::LineItem, :amount => 5) ]}

    context "when payments are sufficient" do
      it "should set payment_state to paid" do
        order.stub(:total => 100.01, :payment_total => 100.012343)
        order.stub(:line_items => line_items)
        order.update!
        order.payment_state.should == "paid"
      end
    end

    context "when payments are insufficient" do
      let(:payments) { mock "payments", :completed => [], :first => mock_model(Spree::Payment, :checkout? => false) }
      before { order.stub :total => 100, :payment_total => 50, :payments => payments }

      context "when last payment did not fail" do
        before { payments.stub :last => mock("payment", :state => 'pending') }
        it "should set payment_state to balance_due" do
          order.update!
          order.payment_state.should == "balance_due"
        end
      end

      context "when last payment failed" do
        before { payments.stub :last => mock("payment", :state => 'failed') }
        it "should set the payment_state to failed" do
          order.update!
          order.payment_state.should == "failed"
        end
      end
    end

    context "when payments are more than sufficient" do
      it "should set the payment_state to credit_owed" do
        order.stub(:total => 100, :payment_total => 150)
        order.stub(:line_items => line_items)
        order.update!
        order.payment_state.should == "credit_owed"
      end
    end

    context "when there are shipments" do
      let(:shipments) { [mock_model(Spree::Shipment, :update! => nil), mock_model(Spree::Shipment, :update! => nil)] }
      before do
        shipments.stub :shipped => []
        shipments.stub :ready => []
        shipments.stub :pending => []
        order.stub :shipments => shipments
      end

      it "should set the correct shipment_state (when all shipments are shipped)" do
        shipments.stub :shipped => [mock_model(Spree::Shipment), mock_model(Spree::Shipment)]
        order.update!
        order.shipment_state.should == "shipped"
      end

      it "should set the correct shipment_state (when some units are backordered)" do
        shipments.stub :shipped => [mock_model(Spree::Shipment)]
        order.stub(:backordered?).and_return true
        order.update!
        order.shipment_state.should == "backorder"
      end

      it "should set the shipment_state to partial (when some of the shipments have shipped)" do
        shipments.stub :shipped => [mock_model(Spree::Shipment)]
        shipments.stub :ready => [mock_model(Spree::Shipment)]
        order.update!
        order.shipment_state.should == "partial"
      end

      it "should set the correct shipment_state (when some of the shipments are ready)" do
        shipments.stub :ready => [mock_model(Spree::Shipment), mock_model(Spree::Shipment)]
        order.update!
        order.shipment_state.should == "ready"
      end

      it "should set the shipment_state to pending (when all shipments are pending)" do
        shipments.stub :pending => [mock_model(Spree::Shipment), mock_model(Spree::Shipment)]
        order.update!
        order.shipment_state.should == "pending"
      end
    end

    context "when there are update hooks" do
      before { Spree::Order.register_update_hook :foo }
      after { Spree::Order.update_hooks.clear }
      it "should call each of the update hooks" do
        order.should_receive :foo
        order.update!
      end
    end

    context "when there is a single checkout payment" do
      before { order.stub(:payment => mock_model(Spree::Payment, :checkout? => true, :amount => 11), :total => 22) }

      it "should update the payment amount to order total" do
        order.payment.should_receive(:update_attributes_without_callbacks).with(:amount => order.total)
        order.update!
      end
    end

    it "should set the correct shipment_state (when there are no shipments)" do
      order.update!
      order.shipment_state.should == nil
    end

    it "should call update_totals" do
      order.should_receive(:update_totals).twice
      order.update!
    end

    it "should call update! on every shipment when Order#update!" do
      shipment = stub_model(Spree::Shipment, :order => order)
      order.stub :shipments => [shipment]
      order.stub(:update_shipment_state) # we don't care about this one

      shipment.should_receive(:update!)
      order.update!
    end
  end

  context "#update_totals" do
    it "should set item_total to the sum of line_item amounts" do
      line_items = [ mock_model(Spree::LineItem, :amount => 100), mock_model(Spree::LineItem, :amount => 50) ]
      order.stub(:line_items => line_items)
      order.update!
      order.item_total.should == 150
    end
    it "should set payments_total to the sum of completed payment amounts" do
      payments = [ mock_model(Spree::Payment, :amount => 100, :checkout? => false), mock_model(Spree::Payment, :amount => -10, :checkout? => false) ]
      payments.stub(:completed => payments)
      order.stub(:payments => payments)
      order.update!
      order.payment_total.should == 90
    end

    context "with adjustments" do
      before do
        create(:adjustment, :adjustable => order, :amount => 10)
        create(:adjustment, :adjustable => order, :amount => 5)
        a = create(:adjustment, :adjustable => order, :amount => -2, :eligible => false)
        a.update_attribute_without_callbacks(:eligible, false)
        order.stub(:update_adjustments, nil) # So the last adjustment remains ineligible
        order.adjustments.reload
      end
      it "should set adjustment_total to the sum of the eligible adjustment amounts" do
        order.update!
        order.adjustment_total.to_i.should == 15
      end
      it "should set the total to the sum of item and adjustment totals" do
        line_items = [ mock_model(Spree::LineItem, :amount => 100), mock_model(Spree::LineItem, :amount => 50) ]
        order.stub(:line_items => line_items)
        order.update!
        order.total.to_i.should == 165
      end
    end

  end

  context "#update_payment_state" do
    it "should set payment_state to balance_due if no line_item" do
      order.stub(:line_items => [])
      order.update!
      order.payment_state.should == "balance_due"
    end
  end

end
