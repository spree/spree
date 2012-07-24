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

  context "#products" do
    before :each do
      @variant1 = mock_model(Spree::Variant, :product => "product1")
      @variant2 = mock_model(Spree::Variant, :product => "product2")
      @line_items = [mock_model(Spree::LineItem, :variant => @variant1, :variant_id => @variant1.id, :quantity => 1),
                     mock_model(Spree::LineItem, :variant => @variant2, :variant_id => @variant2.id, :quantity => 2)]
      order.stub(:line_items => @line_items)
    end

    it "should return ordered products" do
      order.products.should == ['product1', 'product2']
    end

    it "contains?" do
      order.contains?(@variant1).should be_true
    end

    it "gets the quantity of a given variant" do
      order.quantity_of(@variant1).should == 1

      @variant3 = mock_model(Spree::Variant, :product => "product3")
      order.quantity_of(@variant3).should == 0
    end

    it "can find a line item matching a given variant" do
      order.find_line_item_by_variant(@variant1).should_not be_nil
      order.find_line_item_by_variant(mock_model(Spree::Variant)).should be_nil
    end
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
      order.should_receive :touch, :completed_at
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
      adjustment.should_receive(:update_column).with("locked", true)
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

  context "#amount" do
    before do
      @order = create(:order, :user => user)
      @order.line_items = [ create(:line_item, :price => 1.0, :quantity => 2), create(:line_item, :price => 1.0, :quantity => 1) ]
    end
    it "should return the correct lum sum of items" do
      @order.amount.should == 3.0
    end
  end

  context "with adjustments" do
    let(:adjustment1) { mock_model(Spree::Adjustment, :amount => 5) }
    let(:adjustment2) { mock_model(Spree::Adjustment, :amount => 10) }

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

  context "#can_cancel?" do
    it "should be false for completed order in the canceled state" do
      order.state = 'canceled'
      order.shipment_state = 'ready'
      order.completed_at = Time.now
      order.can_cancel?.should be_false
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
    let(:order) { Spree::Order.create(:ship_address => ship_address, :bill_address => bill_address) }
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

  context "#price_adjustments" do
    before do
      @order = Spree::Order.create!
      @order.stub :line_items => [line_item1, line_item2]
    end

    let(:line_item1) { create(:line_item, :order => @order) }
    let(:line_item2) { create(:line_item, :order => @order) }

    context "when there are no line item adjustments" do
      it "should return nothing if line items have no adjustments" do
        @order.price_adjustments.should be_empty
      end
    end

    context "when only one line item has adjustments" do
      before do
        @adj1 = line_item1.adjustments.create({:amount => 2, :source => line_item1, :label => "VAT 5%"}, :without_protection => true)
        @adj2 = line_item1.adjustments.create({:amount => 5, :source => line_item1, :label => "VAT 10%"}, :without_protection => true)
      end

      it "should return the adjustments for that line item" do
         @order.price_adjustments.should =~ [@adj1, @adj2]
      end
    end

    context "when more than one line item has adjustments" do
      before do
        @adj1 = line_item1.adjustments.create({:amount => 2, :source => line_item1, :label => "VAT 5%"}, :without_protection => true)
        @adj2 = line_item2.adjustments.create({:amount => 5, :source => line_item2, :label => "VAT 10%"}, :without_protection => true)
      end

      it "should return the adjustments for each line item" do
        @order.price_adjustments.should == [@adj1, @adj2]
      end
    end
  end

  context "#price_adjustment_totals" do
    before { @order = Spree::Order.create! }


    context "when there are no price adjustments" do
      before { @order.stub :price_adjustments => [] }

      it "should return an empty hash" do
        @order.price_adjustment_totals.should == {}
      end
    end

    context "when there are two adjustments with different labels" do
      let(:adj1) { mock_model Spree::Adjustment, :amount => 10, :label => "Foo" }
      let(:adj2) { mock_model Spree::Adjustment, :amount => 20, :label => "Bar" }

      before do
        @order.stub :price_adjustments => [adj1, adj2]
      end

      it "should return exactly two totals" do
        @order.price_adjustment_totals.size.should == 2
      end

      it "should return the correct totals" do
        @order.price_adjustment_totals["Foo"].should == 10
        @order.price_adjustment_totals["Bar"].should == 20
      end
    end

    context "when there are two adjustments with one label and a single adjustment with another" do
      let(:adj1) { mock_model Spree::Adjustment, :amount => 10, :label => "Foo" }
      let(:adj2) { mock_model Spree::Adjustment, :amount => 20, :label => "Bar" }
      let(:adj3) { mock_model Spree::Adjustment, :amount => 40, :label => "Bar" }

      before do
        @order.stub :price_adjustments => [adj1, adj2, adj3]
      end

      it "should return exactly two totals" do
        @order.price_adjustment_totals.size.should == 2
      end
      it "should return the correct totals" do
        @order.price_adjustment_totals["Foo"].should == 10
        @order.price_adjustment_totals["Bar"].should == 60
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

  context "#add_variant" do
    it "should update order totals" do
      order = Spree::Order.create!

      order.item_total.to_f.should == 0.00
      order.total.to_f.should == 0.00

      product = Spree::Product.create!(:name => 'Test', :sku => 'TEST-1', :price => 22.25)
      order.add_variant(product.master)

      order.item_total.to_f.should == 22.25
      order.total.to_f.should == 22.25
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
