require 'spec_helper'


describe Order do

  let(:order) { Order.new }

  context "#save" do
    it "should create guest user (when no user assigned)" do
      order.save
      order.user.should_not be_nil
      order.user.should be_guest
    end
    it "should not remove the registered user" do
      order = Order.new
      reg_user = mock_model(User)#User.create(:email => "spree@example.com", :password => 'changeme2', :password_confirmation => 'changeme2')
      order.user = reg_user
      order.save
      order.user.should == reg_user
    end
    it "should destroy any line_items with zero quantity"
  end

  context "#register!" do
    it "should change its user to the specified user" do
      order.save
      user = mock_model(User, :guest? => true)
      order.register!(user)
      order.user.should == user
    end
    it "should fail if it already has a registered user" do
      user = mock_model(User, :guest? => false)
      order.save
      expect {
        order.register!(user)
      }.to raise_error
    end
    #TODO think about expected behavior for guest credit cards when changing to registered user, etc.
  end

  context "#next!" do
    it "should finalize order when transitioning to complete state" do
      order.state = "confirm"
      order.should_receive(:finalize!)
      order.next!
    end
  end

  context "#generate_order_number" do
    it "should generate a random string" do
      order.generate_order_number.is_a?(String).should be_true
      (order.generate_order_number.to_s.length > 0).should be_true
    end
  end

  context "#create" do
    it "should assign an order number" do
      order = Order.create
      order.number.should_not be_nil
    end
  end

  context "#finalize!" do

    let(:order) { Order.create }
    it "should set completed_at" do
      order.should_receive :completed_at=
      order.finalize!
    end
    it "should sell inventory units" do
      InventoryUnit.should_receive(:sell_units).with(order)
      order.finalize!
    end
    it "should create a new shipment" do
      line_items = (1..3).map do
        mock_model(LineItem, :amount => 100, :quantity => 1, :variant => mock_model(Variant, :update_attribute => true, :count_on_hand => 100))
      end
      order.stub(:line_items => line_items)
      expect { order.finalize! }.to change{ order.shipments.count }.to(1)
    end
    it "should process the payments" do
      order.stub!(:payments).and_return([mock(Payment)])
      order.payment.should_receive(:process!)
      order.finalize!
    end
  end

  context "#guest?" do
    it "should indicate whether its user is a guest" do
      order.user = mock_model(User, :guest? => true)
      order.should be_guest
      order.user = mock_model(User, :guest? => false)
      order.should_not be_guest
    end
  end

  context "#complete?" do
    it "should indicate if order is complete" do
      order.completed_at = nil
      order.complete?.should be_false

      order.completed_at = Time.now
      order.complete?.should be_true
    end
  end

  context "#backordered?" do
    it "should indicate whether any units in the order are backordered" do
      order.stub_chain(:inventory_units, :backorder).and_return []
      order.backordered?.should be_false
      order.stub_chain(:inventory_units, :backorder).and_return [mock_model(InventoryUnit)]
      order.backordered?.should be_true
    end
  end

  context "#update!" do
    before { Order.should_receive :update_all }
    context "when there are payments" do
      before { order.stub(:total => 100) }
      it "should set the correct payment_state (when payments are sufficient)" do
        order.stub(:payment_total => 100)
        order.update!
        order.payment_state.should == "paid"
      end
      it "should set the correct payment_state (when payments are insufficient)" do
        order.stub(:payment_total => 50)
        order.update!
        order.payment_state.should == "balance_due"
      end
      it "should set the correct payment_state (when payments are more than sufficient)" do
        order.stub(:payment_total => 150)
        order.update!
        order.payment_state.should == "credit_owed"
      end
    end
    context "when there are shipments" do
      before { order.stub_chain(:shipments, :count).and_return 2 }
      it "should set the correct shipment_state (when all shipments are shipped)" do
        order.shipments.stub_chain(:shipped, :count => 2)
        order.shipments.stub_chain(:ready, :count => 0)
        order.update!
        order.shipment_state.should == "shipped"
      end
      it "should set the correct shipment_state (when some units are backordered)" do
        order.shipments.stub_chain(:shipped, :count => 1)
        order.shipments.stub_chain(:ready, :count => 0)
        order.stub(:backordered?).and_return true
        order.update!
        order.shipment_state.should == "backorder"
      end
      it "should set the correct shipment_state (when some of the shipments have shipped)" do
        order.shipments.stub_chain(:shipped, :count => 1)
        order.shipments.stub_chain(:ready, :count => 1)
        order.update!
        order.shipment_state.should == "partial"
      end
      it "should set the correct shipment_state (when some of the shipments are ready)" do
        order.shipments.stub_chain(:shipped, :count => 0)
        order.shipments.stub_chain(:ready, :count => 2)
        order.update!
        order.shipment_state.should == "ready"
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
    it "should call adjustemnt#update on every adjustment}" do
      adjustment = mock_model(Adjustment, :amount => 5, :applicable? => true)
      order.stub(:adjustments => [adjustment])
      adjustment.should_receive(:update)
      order.update!
    end
    it "should destroy adjustments that no longer apply" do
      adjustment = mock_model(Adjustment, :amount => 10, :update => nil, :applicable? => false)
      adjustment.should_receive(:destroy)
      order.stub(:adjustments => [adjustment])
      order.update!
    end
    it "should not destroy adjustments that still apply" do
      adjustment = mock_model(Adjustment, :amount => 10, :update => nil, :applicable? => true)
      adjustment.should_not_receive(:destroy)
      order.stub(:adjustments => [adjustment])
      order.update!
    end
  end

  context "#update_totals" do
    it "should set item_total to the sum of line_item amounts" do
      line_items = [ mock_model(LineItem, :amount => 100), mock_model(LineItem, :amount => 50) ]
      order.stub(:line_items => line_items)
      order.update!
      order.item_total.should == 150
    end
    it "should set payments_total to the sum of completed payment amounts" do
      payments = [ mock_model(Payment, :amount => 100), mock_model(Payment, :amount => -10) ]
      order.stub_chain(:payments, :completed => payments)
      order.update!
      order.payment_total.should == 90
    end
    context "with adjustments" do
      let(:adjustments) {
        [ mock_model(Adjustment, :amount => 10, :update => nil, :applicable? => true),
          mock_model(Adjustment, :amount => 5,  :update => nil, :applicable? => true),
          mock_model(Adjustment, :amount => -2, :update => nil, :applicable? => true) ]
      }
      before { order.stub(:adjustments => adjustments) }
      it "should set adjustment_total to the sum of adjustment amounts" do
        order.update!
        order.adjustment_total.should == 13
      end
      it "should set the total to the sum of item and adjustment totals" do
        line_items = [ mock_model(LineItem, :amount => 100), mock_model(LineItem, :amount => 50) ]
        order.stub(:line_items => line_items)
        order.update!
        order.total.should == 163
      end
    end
  end

  context "#allow_checkout?" do
    it "should be true if there are line_items in the order" do
      order.stub_chain(:line_items, :count => 1)
      order.checkout_allowed?.should be_true
    end
    it "should be false if there are no line_items in the order" do
      order.stub_chain(:line_items, :count => 0)
      order.checkout_allowed?.should be_false
    end
  end

  context "item_count" do
    it "should return the correct number of items" do
      line_items = [ mock_model(LineItem, :quantity => 2), mock_model(LineItem, :quantity => 1) ]
      order.stub :line_items => line_items
      order.item_count.should == 3
    end
  end
end
