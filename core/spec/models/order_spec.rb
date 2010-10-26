require File.dirname(__FILE__) + '/../spec_helper'

describe Order do

  let(:order) { Order.new(:email => "foo@example.com") }
  let(:gateway) { Gateway::Bogus.new(:name => "Credit Card", :active => true) }

  before { Gateway.stub :current => gateway }

  context "#save" do
    it "should create guest user (when no user assigned)" do
      order.save
      order.user.should_not be_nil
      order.user.should be_anonymous
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

  context "#next!" do
    context "when current state is confirm" do
      before { order.state = "confirm" }
      it "should finalize order when transitioning to complete state" do
        order.should_receive(:finalize!)
        order.next!
      end

       context "when credit card payment fails" do
         before do
           order.stub(:process_payments!).and_raise(Spree::GatewayError)
         end

         context "when not configured to allow failed payments" do
            before do
              Spree::Config.set :allow_checkout_on_gateway_error => false
            end

            it "should not complete the order" do
               order.next
               order.state.should == "confirm"
             end
          end

         context "when configured to allow failed payments" do
           before do
             Spree::Config.set :allow_checkout_on_gateway_error => true
           end

           it "should complete the order" do
              order.next
              order.state.should == "complete"
            end

         end

       end
    end
    context "when current state is address" do
      let(:rate) { mock_model TaxRate, :amount => 10 }

      before do
        order.state = "address"
        TaxRate.stub :match => rate
      end

      it "should create a tax charge when transitioning to delivery state" do
        rate.should_receive(:create_adjustment).with(I18n.t(:tax), order, order, true)
        order.next!
      end

      context "when a tax charge already exists" do
        let(:old_charge) { mock_model Adjustment }
        before { order.stub_chain :adjustments, :tax => [old_charge] }

        it "should not create a second tax charge (for the same rate)" do
          old_charge.stub :originator => rate
          rate.should_not_receive :create_adjustment
          order.next!
        end

        it "should remove an existing tax charge (for the old rate)" do
          old_charge.stub :originator => mock_model(TaxRate)
          old_charge.should_receive :destroy
          order.next
        end

        it "should remove an existing tax charge if there is no longer a relevant tax rate" do
          TaxRate.stub :match => nil
          old_charge.stub :originator => mock_model(TaxRate)
          old_charge.should_receive :destroy
          order.next
        end
      end

    end


    context "when current state is delivery" do
      let(:shipping_method) { mock_model(ShippingMethod).as_null_object }
      let(:units) { [mock_model(InventoryUnit)] }

      before do
        Shipment.stub(:create).and_return(mock_model(Shipment).as_null_object)
        order.state = "delivery"
        order.stub :shipping_method => shipping_method
        order.stub :inventory_units => units
      end
      context "when transitioning to payment state" do
        before do
        end
        it "should create a shipment" do
          Shipment.should_receive(:create).with(:shipping_method => order.shipping_method, :order => order, :address => order.ship_address)
          order.next!
        end
        it "should create a shipping charge" do
          order.stub(:shipment).and_return(mock_model(Shipment).as_null_object)
          order.shipping_method.should_receive(:create_adjustment).with(I18n.t(:shipping), order, order.shipment, true)
          order.next!
        end
      end
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
      InventoryUnit.should_receive(:assign_opening_inventory).with(order)
      order.finalize!
    end
    it "should change the shipment state to ready if order is paid"

    after { Spree::Config.set :track_inventory_levels => true }
    it "should not sell inventory units if track_inventory_levels is false" do
      Spree::Config.set :track_inventory_levels => false
      InventoryUnit.should_not_receive(:sell_units)
      order.finalize!
    end

    it "should send an order confirmation email" do
      mail_message = mock "Mail::Message"
      OrderMailer.should_receive(:confirm_email).with(order).and_return mail_message
      mail_message.should_receive :deliver
      order.finalize!
    end

    it "should freeze optional adjustments" do
      OrderMailer.stub_chain :confirm_email, :deliver
      adjustment = mock_model(Adjustment)
      order.stub_chain :adjustments, :optional => [adjustment]
      adjustment.should_receive(:update_attribute).with("locked", true)
      order.finalize!
    end
  end

  context "#process_payments!" do
    it "should process the payments" do
      order.stub!(:payments).and_return([mock(Payment)])
      order.payment.should_receive(:process!)
      order.process_payments!
    end
  end

  context "#anonymous?" do
    it "should indicate whether its user is a guest" do
      order.user = mock_model(User, :anonymous? => true)
      order.should be_anonymous
      order.user = mock_model(User, :anonymous? => false)
      order.should_not be_anonymous
    end
  end

  context "#outstanding_balance" do
    it "should return the value total - payment_total" do
      order.payment_total = 20.20
      order.total = 30.30
      order.outstanding_balance.should == 10.10
    end
  end

  context "#outstanding_balance?" do
    it "should return true when total greater than payment_total" do
      order.total = 10.10
      order.payment_total = 9.50
      order.outstanding_balance?.should be_true
    end
    it "should return false when total less than payment_total" do
      order.total = 8.25
      order.payment_total = 10.44
      order.outstanding_balance?.should be_false
    end
    it "should return false when total equals payment_total" do
      order.total = 10.10
      order.payment_total = 10.10
      order.outstanding_balance?.should be_false
    end
  end

  context "#outstanding_credit" do
    it "should return 0 when payment_total is less than total" do
      order.total = 10.10
      order.payment_total = 8.52
      order.outstanding_credit.should == 0
    end
    it "should return payment_total - total when payment_total is greater than total" do
      order.total = 8.20
      order.payment_total = 10.20
      order.outstanding_credit.should == 2.00
    end
  end

  context "#outstanding_credit?" do
    it "should be true when there's outstanding credit" do
      order.total = 2.50
      order.payment_total = 8.20
      order.outstanding_credit?.should be_true
    end
    it "should be false when there's no outstanding credit" do
      order.total = 11.20
      order.payment_total = 8.20
      order.outstanding_credit?.should be_false
    end
  end

  context "#complete?" do
    it "should indicate if order is complete" do
      order.completed_at = nil
      order.complete?.should be_false

      order.completed_at = Time.now
      order.completed?.should be_true
    end
  end

  context "#backordered?" do
    it "should indicate whether any units in the order are backordered" do
      order.stub_chain(:inventory_units, :backorder).and_return []
      order.backordered?.should be_false
      order.stub_chain(:inventory_units, :backorder).and_return [mock_model(InventoryUnit)]
      order.backordered?.should be_true
    end

    it "should always be false when inventory tracking is disabled" do
      Spree::Config.set :track_inventory_levels => false
      order.stub_chain(:inventory_units, :backorder).and_return [mock_model(InventoryUnit)]
      order.backordered?.should be_false
    end
  end

  context "#update!" do
    before { Order.should_receive :update_all }

    context "when payments are sufficient" do
      it "should set payment_state to paid" do
        order.stub(:total => 100, :payment_total => 100)
        order.update!
        order.payment_state.should == "paid"
      end
    end

    context "when payments are insufficient" do
      let(:payments) { mock "payments", :completed => [] }
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
        order.update!
        order.payment_state.should == "credit_owed"
      end
    end

    context "when there are shipments" do
      before do
        order.stub_chain :shipments, :count => 2
        order.shipments.stub_chain(:shipped, :count => 0)
        order.shipments.stub_chain(:ready, :count => 0)
        order.shipments.stub_chain(:pending, :count => 0)
        order.shipments.stub :each => nil
      end

      it "should set the correct shipment_state (when all shipments are shipped)" do
        order.shipments.stub_chain(:shipped, :count => 2)
        order.update!
        order.shipment_state.should == "shipped"
      end

      it "should set the correct shipment_state (when some units are backordered)" do
        order.shipments.stub_chain(:shipped, :count => 1)
        order.stub(:backordered?).and_return true
        order.update!
        order.shipment_state.should == "backorder"
      end

      it "should set the shipment_state to partial (when some of the shipments have shipped)" do
        order.shipments.stub_chain(:shipped, :count => 1)
        order.shipments.stub_chain(:ready, :count => 1)
        order.update!
        order.shipment_state.should == "partial"
      end

      it "should set the correct shipment_state (when some of the shipments are ready)" do
        order.shipments.stub_chain(:ready, :count => 2)
        order.update!
        order.shipment_state.should == "ready"
      end

      it "should set the shipment_state to pending (when all shipments are pending)" do
        order.shipments.stub_chain(:pending, :count => 2)
        order.update!
        order.shipment_state.should == "pending"
      end
    end

    context "when there are update hooks" do
      before { Order.register_update_hook :foo }
      after { Order.update_hooks.clear }
      it "should call each of the update hooks" do
        order.should_receive :foo
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

    it "should call adjustemnt#update on every adjustment}" do
      adjustment = mock_model(Adjustment, :amount => 5, :applicable? => true, :update! => true)
      order.stub(:adjustments => [adjustment])
      order.adjustments.stub(:reload).and_return([adjustment])
      adjustment.should_receive(:update!)
      order.update!
    end

    it "should destroy adjustments that no longer apply" do
      adjustment = mock_model(Adjustment, :amount => 10, :update! => true, :applicable? => false)
      adjustment.should_receive(:destroy)
      order.stub(:adjustments => [adjustment])
      order.adjustments.stub(:reload).and_return([adjustment])
      order.update!
    end

    it "should not destroy adjustments that still apply" do
      adjustment = mock_model(Adjustment, :amount => 10, :update! => true, :applicable? => true)
      adjustment.should_not_receive(:destroy)
      order.stub(:adjustments => [adjustment])
      order.adjustments.stub(:reload).and_return([adjustment])
      order.update!
    end

    it "should call update! on every shipment" do
      shipment = mock_model Shipment
      order.shipments = [shipment]
      shipment.should_receive(:update!)
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
        [ mock_model(Adjustment, :amount => 10, :update! => true, :applicable? => true),
          mock_model(Adjustment, :amount => 5,  :update! => true, :applicable? => true),
          mock_model(Adjustment, :amount => -2, :update! => true, :applicable? => true) ]
      }
      before do
        order.stub(:adjustments => adjustments)
        order.adjustments.stub(:reload).and_return(adjustments)
      end
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

  context "in the cart state" do
    it "should not validate email address" do
      order.state = "cart"
      order.email = nil
      order.should be_valid
    end
  end

  context "#can_cancel?" do

    [PENDING, BACKORDER, READY].each do |shipment_state|
      it "should be true if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be_true
      end
    end

    (SHIPMENT_STATES - [PENDING, BACKORDER, READY]).each do |shipment_state|
      it "should be false if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be_false
      end
    end

  end

  context "#cancel" do
    before do
      order.stub :completed? => true
      order.stub :allow_cancel? => true
    end
    it "should send a cancel email" do
      mail_message = mock "Mail::Message"
      OrderMailer.should_receive(:cancel_email).with(order).and_return mail_message
      mail_message.should_receive :deliver
      order.cancel!
    end
    it "should restock inventory"
    it "should change shipment status (unless shipped)"
  end

  context "#shipped_units" do
    let(:unit_1) { InventoryUnit.create(:variant => mock_model(Variant), :state => "shipped") }
    let(:unit_2) { InventoryUnit.create(:variant => mock_model(Variant), :state => "shipped") }
    let(:unit_3) { InventoryUnit.create(:variant => mock_model(Variant), :state => "sold") }

    before do
      order.stub(:inventory_units => [unit_1, unit_2, unit_1, unit_3])
    end

    it "should return shipped unit count grouped by variant" do
      order.shipped_units.should == {unit_1.variant => 2, unit_2.variant => 1}
    end

  end

  context "#returnable_units" do
    let(:unit_1) { InventoryUnit.create(:variant => mock_model(Variant), :variant_id => 1, :state => "shipped") }
    let(:unit_2) { InventoryUnit.create(:variant => mock_model(Variant), :variant_id => 2, :state => "returned") }
    let(:unit_3) { InventoryUnit.create(:variant => mock_model(Variant), :variant_id => 3, :state => "sold") }

    before do
      order.stub(:inventory_units => [unit_1, unit_2, unit_1, unit_3])
    end

    it "should list all returnable units" do
      order.returnable_units.should == { unit_1.variant => 2 }
    end

  end

  context "with adjustments" do
    let(:adjustment1) { mock_model(Adjustment, :amount => 5) }
    let(:adjustment2) { mock_model(Adjustment, :amount => 10) }

    context "#ship_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :shipping => [adjustment1, adjustment2]
        order.ship_total.should == 15
      end
    end

    context "#tax_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :tax => [adjustment1, adjustment2]
        order.tax_total.should == 15
      end
    end
  end

end
