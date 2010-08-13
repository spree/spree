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





  context "Totaling" do

    context "#calculate_totals" do
      it "should call update_adjustments"
      it "should set item_total to the sum of line_item amounts"
      it "should set payments_total to the sum of payment amounts"
      it "should set adjustment_total to the sum of adjustment amounts"
      it "should set the total to the sum of item and adjustment totals"
      it "should set outstanding_balance to the difference between the total and payment_total"
    end

    context "#update_adjustments" do
      it "should destroy inapplicatable adjustments"
      it "should force the adjustments to recalculate their amounts"
    end

    context "#update_totals" do
      it "should update the relevant database columns sucessfully"
      it "should not save associated objects"
    end

    context "#destroy_inapplicable_adjustments" do
      it "should destroy adjustments for which applicable? is false"
      it "should remove the destroyed adjustments from the association collection"
    end

  end

end
