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

  context "#finalize!" do
    it "should set completed_at" do
      order.finalize!
      order.completed_at.should_not be_nil
    end
    it "should sell inventory units" do
      InventoryUnit.should_receive(:sell_units).with(order)
      order.finalize!
    end
    pending "should create a new shipment" do
      expect { order.finalize! }.to change{ order.shipments.count }.to(1)
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
      order.should_receive(:update_totals)
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
    it "should set payments_total to the sum of finalized payment amounts" do
      payments = [ mock_model(Payment, :amount => 100), mock_model(Payment, :amount => -10) ]
      order.stub_chain(:payments, :finalized => payments)
      order.update!
      order.payment_total.should == 90
    end
    it "should set adjustment_total to the sum of adjustment amounts" do
      adjustments = [ mock_model(Adjustment, :amount => 10), mock_model(Adjustment, :amount => 5), mock_model(Adjustment, :amount => -2) ]
      order.stub(:adjustments => adjustments)
      order.update!
      order.adjustment_total.should == 13
    end
    it "should set the total to the sum of item and adjustment totals" do
      line_items = [ mock_model(LineItem, :amount => 100), mock_model(LineItem, :amount => 50) ]
      order.stub(:line_items => line_items)
      adjustments = [ mock_model(Adjustment, :amount => 10), mock_model(Adjustment, :amount => 5), mock_model(Adjustment, :amount => -2) ]
      order.stub(:adjustments => adjustments)
      order.update!
      order.total.should == 163
    end
  end

  context "Totaling" do
    before(:all) do
      order.save
    end

    context "#update_adjustments" do
      it "should destroy inapplicatable adjustments"
      it "should force the adjustments to recalculate their amounts"
    end

    context "#destroy_inapplicable_adjustments" do
      before(:all) do
        order.adjustments.clear
        order.tax_charges.create!(:description => 'tax', :adjustment_source => order, :amount => 10)
        order.shipping_charges.create!(:description => 'shipping', :amount => 20)
        order.adjustments.reload
        @inapplicable = order.adjustments.first
        @inapplicable.stub!(:applicable?).and_return(false)
        order.destroy_inapplicable_adjustments
      end
      it "should destroy adjustments for which applicable? is false" do
        Adjustment.exists?(@inapplicable.id).should be_false
      end
      it "should remove the destroyed adjustments from the association collection" do
        order.adjustments.length.should == 1
        order.adjustments.include?(@inapplicable).should be_false
      end
    end

  end

end
