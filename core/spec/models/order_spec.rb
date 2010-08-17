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

  context "Totaling" do
    before(:all) do
      order.save
    end

    context "#calculate_totals" do
      before(:all) do
        # add line items
        3.times { Fabricate(:line_item, :price => 100, :order => order) }
        # payments
        payment = order.payments.build(:amount => 300, :state => 'finalized')
        payment.order.stub!(:outstanding_balance).and_return(300) # so payment will validate
        payment.save!
        # and adjustments
        order.tax_charges.create!(:description => 'tax', :adjustment_source => order, :amount => 10)
        order.shipping_charges.create!(:description => 'shipping', :amount => 20)
        order.reload

        order.calculate_totals
      end

      it "should set item_total to the sum of line_item amounts" do
        order.item_total.to_i.should == 300
      end
      it "should set payments_total to the sum of payment amounts" do
        order.payment_total.to_i.should == 300
      end
      it "should set adjustment_total to the sum of adjustment amounts" do
        order.adjustment_total.to_i.should == 30
      end
      it "should set the total to the sum of item and adjustment totals" do
        order.total.to_i.should == 330
      end
      # it "should set outstanding_balance to the difference between the total and payment_total"
    end

    context "#update_adjustments" do
      it "should destroy inapplicatable adjustments"
      it "should force the adjustments to recalculate their amounts"
    end

    context "#update_totals" do
      it "should update the relevant database columns sucessfully" do
        order.stub!(:calculate_totals)
        order.item_total = 1
        order.adjustment_total = 2
        order.payment_total = 3
        order.update_totals!
        order.reload
        order.item_total.to_i.should == 1
        order.adjustment_total.to_i.should == 2
        order.payment_total.to_i.should == 3
      end
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

    context "adding a line item" do
      it "should increase the item_total" do
        order.reload
        lambda do
          order.line_items.create Fabricate.attributes_for(:line_item, :quantity => 1, :price => 100)
          order.reload
        end.should change(order, :item_total).by(100)
      end
    end

    context "#payment_state" do
      it "should return :credit_owed if finalized payments total is more than order total"
      it "should return :balance_due if finalized payments total is less than order total"
      it "should return :paid if finalized payments total matches order total"
    end

    context "#shipment-state" do
      it "should return :shipped if all shipments are shipped"
    end

  end

end
