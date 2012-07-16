require 'spec_helper'

class FakeCalculator < Spree::Calculator
  def compute(computable)
    5
  end
end

describe Spree::Order do
  before(:each) do
    reset_spree_preferences
    Spree::Gateway.create({:name => 'Test', :active => true, :environment => 'test', :description => 'foofah'}, :without_protection => true)
  end

  let(:user) { stub_model(Spree::User, :email => "spree@example.com") }
  let(:order) { stub_model(Spree::Order, :user => user) }
  let(:gateway) { Spree::Gateway::Bogus.new({:name => "Credit Card", :active => true}, :without_protection => true) }

  before do
    Spree::Gateway.stub :current => gateway
    Spree::User.stub(:current => mock_model(Spree::User, :id => 123))
  end

  context "validation" do
    context "email validation" do
      # Regression test for #1238
      it "o'brien@gmail.com is a valid email address" do
        order.state = 'address'
        order.email = "o'brien@gmail.com"
        order.should be_valid
      end
    end
  end

  context "#save" do
    it "should create guest user (when no user assigned)" do
      order.run_callbacks(:create)
      order.user.should_not be_nil
    end

    context "when associated with a registered user" do
      it "should assign the email address of the user" do
        order.run_callbacks(:create)
        order.email.should == user.email
      end

      it "should accept the sample admin email address" do
        user.stub :email => "spree@example.com"
        order.run_callbacks(:create)
        order.email.should == user.email
      end

      it "should reject the automatic email for anonymous users" do
        user.stub :anonymous? => true
        order.email.should be_blank
      end

    end

    it "should destroy any line_items with zero quantity"
  end

  context "#generate_order_number" do
    it "should generate a random string" do
      order.generate_order_number.is_a?(String).should be_true
      (order.generate_order_number.to_s.length > 0).should be_true
    end
  end

  context "#associate_user!" do
    it "should associate a user with this order" do
      order.user = nil
      order.email = nil
      order.associate_user!(user)
      order.user.should == user
      order.email.should == user.email
    end
  end

  context "#create" do
    it "should assign an order number" do
      order = Spree::Order.create
      order.number.should_not be_nil
    end
  end

  context "#finalize!" do
    let(:order) { Spree::Order.create }
    it "should set completed_at" do
      order.should_receive :completed_at=
      order.finalize!
    end
    it "should sell inventory units" do
      Spree::InventoryUnit.should_receive(:assign_opening_inventory).with(order)
      order.finalize!
    end
    it "should change the shipment state to ready if order is paid"

    after { Spree::Config.set :track_inventory_levels => true }
    it "should not sell inventory units if track_inventory_levels is false" do
      Spree::Config.set :track_inventory_levels => false
      Spree::InventoryUnit.should_not_receive(:sell_units)
      order.finalize!
    end

    it "should send an order confirmation email" do
      mail_message = mock "Mail::Message"
      Spree::OrderMailer.should_receive(:confirm_email).with(order).and_return mail_message
      mail_message.should_receive :deliver
      order.finalize!
    end

    it "should continue even if confirmation email delivery fails" do
      Spree::OrderMailer.should_receive(:confirm_email).with(order).and_raise 'send failed!'
      order.finalize!
    end

    it "should freeze optional adjustments" do
      Spree::OrderMailer.stub_chain :confirm_email, :deliver
      adjustment = mock_model(Spree::Adjustment)
      order.stub_chain :adjustments, :optional => [adjustment]
      adjustment.should_receive(:update_attribute).with("locked", true)
      order.finalize!
    end

    it "should log state event" do
      order.state_changes.should_receive(:create)
      order.finalize!
    end
  end

  context "#process_payments!" do
    it "should process the payments" do
      order.stub!(:payments).and_return([mock(Spree::Payment)])
      order.payment.should_receive(:process!)
      order.process_payments!
    end
  end

  context "#outstanding_balance" do
    it "should return positive amount when payment_total is less than total" do
      order.payment_total = 20.20
      order.total = 30.30
      order.outstanding_balance.should == 10.10
    end
    it "should return negative amount when payment_total is greater than total" do
      order.total = 8.20
      order.payment_total = 10.20
      order.outstanding_balance.should be_within(0.001).of(-2.00)
    end

  end

  context "#outstanding_balance?" do
    it "should be true when total greater than payment_total" do
      order.total = 10.10
      order.payment_total = 9.50
      order.outstanding_balance?.should be_true
    end
    it "should be true when total less than payment_total" do
      order.total = 8.25
      order.payment_total = 10.44
      order.outstanding_balance?.should be_true
    end
    it "should be false when total equals payment_total" do
      order.total = 10.10
      order.payment_total = 10.10
      order.outstanding_balance?.should be_false
    end
  end

  context "#outstanding_credit" do
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
      order.stub_chain(:inventory_units, :backorder).and_return [mock_model(Spree::InventoryUnit)]
      order.backordered?.should be_true
    end

    it "should always be false when inventory tracking is disabled" do
      pending
      Spree::Config.set :track_inventory_levels => false
      order.stub_chain(:inventory_units, :backorder).and_return [mock_model(Spree::InventoryUnit)]
      order.backordered?.should be_false
    end
  end

  context "#payment_method" do
    it "should return payment.payment_method if payment is present" do
      payments = [create(:payment)]
      payments.stub(:completed => payments)
      order.stub(:payments => payments)
      order.payment_method.should == order.payments.first.payment_method
    end

    it "should return the first payment method from available_payment_methods if payment is not present" do
      create(:payment_method, :environment => 'test')
      order.payment_method.should == order.available_payment_methods.first
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

  context "#item_count" do
    before do
      @order = create(:order, :user => user)
      @order.line_items = [ create(:line_item, :quantity => 2), create(:line_item, :quantity => 1) ]
    end
    it "should return the correct number of items" do
      @order.item_count.should == 3
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

    %w(pending backorder ready).each do |shipment_state|
      it "should be true if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be_true
      end
    end

    (SHIPMENT_STATES - %w(pending backorder ready)).each do |shipment_state|
      it "should be false if shipment_state is #{shipment_state}" do
        order.stub :completed? => true
        order.shipment_state = shipment_state
        order.can_cancel?.should be_false
      end
    end

  end

  context "#cancel" do
    let!(:variant) { stub_model(Spree::Variant, :on_hand => 0) }
    let!(:inventory_units) { [stub_model(Spree::InventoryUnit, :variant => variant),
                              stub_model(Spree::InventoryUnit, :variant => variant) ]}
    let!(:shipment) do
      shipment = stub_model(Spree::Shipment)
      shipment.stub :inventory_units => inventory_units
      order.stub :shipments => [shipment]
      shipment
    end

    before do
      order.email = user.email
      order.stub :line_items => [stub_model(Spree::LineItem, :variant => variant, :quantity => 2)]
      order.line_items.stub :find_by_variant_id => order.line_items.first

      order.stub :completed? => true
      order.stub :allow_cancel? => true
    end

    it "should send a cancel email" do
      order.stub :restock_items!
      mail_message = mock "Mail::Message"
      Spree::OrderMailer.should_receive(:cancel_email).with(order).and_return mail_message
      mail_message.should_receive :deliver
      order.cancel!
    end

    context "restocking inventory" do
      before do
        shipment.stub(:ensure_correct_adjustment)
        shipment.stub(:update_order)
        Spree::OrderMailer.stub(:cancel_email).and_return(mail_message = stub)
        mail_message.stub :deliver
      end

      # Regression fix for #729
      specify do
        Spree::InventoryUnit.should_receive(:decrease).with(order, variant, 2).once
        order.cancel!
      end

    end

    it "should change shipment status (unless shipped)"
  end


  # Another regression test for #729
  context "#resume" do
    before do
      order.stub :email => "user@spreecommerce.com"
      order.stub :state => "canceled"
      order.stub :allow_resume? => true
    end

    it "should send a resume email" do
      pending "Pending test for #818"
      order.stub :unstock_items!
      order.resume!
    end

    context "unstocks inventory" do
      let(:variant) { stub_model(Spree::Variant) }

      before do
        shipment = stub_model(Spree::Shipment)
        line_item = stub_model(Spree::LineItem, :variant => variant, :quantity => 2)
        order.stub :line_items => [line_item]
        order.line_items.stub :find_by_variant_id => line_item

        order.stub :shipments => [shipment]
        shipment.stub :inventory_units => [stub_model(Spree::InventoryUnit, :variant => variant),
                                           stub_model(Spree::InventoryUnit, :variant => variant) ]
      end

      specify do
        Spree::InventoryUnit.should_receive(:increase).with(order, variant, 2).once
        order.resume!
      end
    end
  end

  context "rate_hash" do
    let(:shipping_method_1) { mock_model Spree::ShippingMethod, :name => 'Air Shipping', :id => 1, :calculator => mock('calculator') }
    let(:shipping_method_2) { mock_model Spree::ShippingMethod, :name => 'Ground Shipping', :id => 2, :calculator => mock('calculator') }

    before do
      shipping_method_1.calculator.stub(:compute).and_return(10.0)
      shipping_method_2.calculator.stub(:compute).and_return(0.0)
      order.stub(:available_shipping_methods => [ shipping_method_1, shipping_method_2 ])
    end

    it "should return shipping methods sorted by cost" do
      rate_1, rate_2 = order.rate_hash

      rate_1.shipping_method.should == shipping_method_2
      rate_1.cost.should == 0.0
      rate_1.name.should == "Ground Shipping"
      rate_1.id.should == 2

      rate_2.shipping_method.should == shipping_method_1
      rate_2.cost.should == 10.0
      rate_2.name.should == "Air Shipping"
      rate_2.id.should == 1
    end

    it "should not return shipping methods with nil cost" do
      shipping_method_1.calculator.stub(:compute).and_return(nil)
      order.rate_hash.count.should == 1
      rate_1 = order.rate_hash.first

      rate_1.shipping_method.should == shipping_method_2
      rate_1.cost.should == 0
      rate_1.name.should == "Ground Shipping"
      rate_1.id.should == 2
    end

  end

  context "insufficient_stock_lines" do
    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }

    before { order.stub(:line_items => [line_item]) }

    it "should return line_item that has insufficent stock on hand" do
      order.insufficient_stock_lines.size.should == 1
      order.insufficient_stock_lines.include?(line_item).should be_true
    end

  end

  context "clear_adjustments" do
    before do
      @order = Spree::Order.new
    end

    it "should destroy all previous tax adjustments" do
      adjustment = mock_model(Spree::Adjustment)
      adjustment.should_receive :destroy

      @order.stub_chain :adjustments, :tax => [adjustment]
      @order.clear_adjustments!
    end

    it "should destroy all price adjustments" do
      adjustment = mock_model(Spree::Adjustment)
      adjustment.should_receive :destroy

      @order.stub :price_adjustments => [adjustment]
      @order.clear_adjustments!
    end
  end

  context "#tax_zone" do
    let(:bill_address) { Factory :address }
    let(:ship_address) { Factory :address }
    let(:order) do
      Spree::Order.create({
        :ship_address => ship_address,
        :bill_address => bill_address
      }, :without_protection => true)
    end
    let(:zone) { Factory :zone }

    context "when no zones exist" do
      before { Spree::Zone.destroy_all }

      it "should return nil" do
        order.tax_zone.should be_nil
      end
    end

    context "when :tax_using_ship_address => true" do
      before { Spree::Config.set(:tax_using_ship_address => true) }

      it "should calculate using ship_address" do
        Spree::Zone.should_receive(:match).at_least(:once).with(ship_address)
        Spree::Zone.should_not_receive(:match).with(bill_address)
        order.tax_zone
      end
    end

    context "when :tax_using_ship_address => false" do
      before { Spree::Config.set(:tax_using_ship_address => false) }

      it "should calculate using bill_address" do
        Spree::Zone.should_receive(:match).at_least(:once).with(bill_address)
        Spree::Zone.should_not_receive(:match).with(ship_address)
        order.tax_zone
      end
    end

    context "when there is a default tax zone" do
      before do
        @default_zone = create(:zone, :name => "foo_zone")
        Spree::Zone.stub :default_tax => @default_zone
      end

      context "when there is a matching zone" do
        before { Spree::Zone.stub(:match => zone) }

        it "should return the matching zone" do
          order.tax_zone.should == zone
        end
      end

      context "when there is no matching zone" do
        before { Spree::Zone.stub(:match => nil) }

        it "should return the default tax zone" do
          order.tax_zone.should == @default_zone
        end
      end
    end

    context "when no default tax zone" do
      before { Spree::Zone.stub :default_tax => nil }

      context "when there is a matching zone" do
        before { Spree::Zone.stub(:match => zone) }

        it "should return the matching zone" do
          order.tax_zone.should == zone
        end
      end

      context "when there is no matching zone" do
        before { Spree::Zone.stub(:match => nil) }

        it "should return nil" do
          order.tax_zone.should be_nil
        end
      end
    end
  end

  context "#exclude_tax?" do
    before do
      @order = create(:order)
      @default_zone = create(:zone)
      Spree::Zone.stub :default_tax => @default_zone
    end

    context "when prices include tax" do
      before { Spree::Config.set(:prices_inc_tax => true) }

      it "should be true when tax_zone is not the same as the default" do
        @order.stub :tax_zone => create(:zone, :name => "other_zone")
        @order.exclude_tax?.should be_true
      end

      it "should be false when tax_zone is the same as the default" do
        @order.stub :tax_zone => @default_zone
        @order.exclude_tax?.should be_false
      end
    end

    context "when prices do not include tax" do
      before { Spree::Config.set(:prices_inc_tax => false) }

      it "should be false" do
        @order.exclude_tax?.should be_false
      end
    end
  end

  context "empty!" do
    it "should clear out all line items and adjustments" do
      order = stub_model(Spree::Order)
      order.stub(:line_items => line_items = [])
      order.stub(:adjustments => adjustments = [])
      order.line_items.should_receive(:destroy_all)
      order.adjustments.should_receive(:destroy_all)

      order.empty!
    end
  end
end
