require 'test_helper'

class CheckoutTest < ActiveSupport::TestCase
  fixtures :gateways

  should_belong_to :bill_address
  should_not_allow_values_for :email, "blah", "b lah", "blah@blah"

  context Checkout do
    setup do
      @checkout = Factory(:order_with_totals).checkout
       @checkout.state = "confirm"
      @checkout.creditcard = Factory(:creditcard)
    end
    context "in confirm state w/no auto capture" do
      setup do

        Spree::Config.set(:auto_capture => false)
      end
      context "next" do
        setup { @checkout.next! }
        should_change("@checkout.state", :to => "complete") { @checkout.state }
        should_change("@checkout.order.completed_at", :from => nil) { @checkout.order.completed_at }
        should_change("@checkout.order.state", :from => "in_progress", :to => "new") { @checkout.order.state }
        should_not_change("@checkout.order.creditcard_payments.count") { @checkout.order.creditcard_payments.count }
        should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      end
      context "next with declineable creditcard" do
        setup do
          @checkout.creditcard.number = "4111111111111110"
          @checkout.creditcard.save
          begin @checkout.next! rescue Spree::GatewayError end
        end
        should_not_change("Creditcard.count") { Creditcard.count }
        should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
        should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
        should_not_change("@checkout.state") { @checkout.state }
      end
    end
    context "in payment state w/auto capture" do
      setup do

        Spree::Config.set(:auto_capture => true)
      end
      context "next" do
        setup { @checkout.next! }

        should_change("@checkout.state", :to => "complete") { @checkout.state }
        should_change("@checkout.order.completed_at", :from => nil) { @checkout.order.completed_at }
        should_change("@checkout.order.state", :from => "in_progress", :to => "paid") { @checkout.order.state }
        should_change("@checkout.order.creditcard_payments.count", :by => 1) { @checkout.order.creditcard_payments.count }
        should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      end
    end
    context "on update" do
      setup do
        @order = Factory(:order)
        @checkout = @order.checkout
        @checkout.bill_address = Factory(:address)
        @checkout.ship_address = Factory(:address)
        @shipping_method = Factory(:shipping_method)
        @checkout.save
      end
      should "update shipping method of order's default shipment" do
        @checkout.shipping_method = @checkout.shipping_methods.first
        assert_nil @order.shipment.shipping_method
        @checkout.save
        assert_equal @checkout.shipping_method, @order.shipment.shipping_method, "default shipment shipping_method didn't match shipping_method of checkout"
      end
      should "update address of order's default shipment" do
        assert_equal @checkout.ship_address, @order.shipment.address, "default shipment address didn't match ship address from checkout"
      end
    end
  end
  context "Checkout#countries" do
    setup do
      3.times { Factory(:country) }
      @country = Factory(:country)
      zone_member = ZoneMember.create(:zoneable => @country)
      @zone = Zone.create(:name => Faker::Lorem.words, :description => Faker::Lorem.sentence, :zone_members => [zone_member])
    end
    context "with no checkout zone defined" do
      setup { Spree::Config.set(:checkout_zone => nil) }
      should "return complete list of countries" do
        assert_equal Country.count, Checkout.countries.size
      end
    end
    context "with a checkout zone defined" do
      setup { Spree::Config.set(:checkout_zone => @zone.name) }
      should "return only the countries defined by the checkout zone" do
        assert_equal [@country], Checkout.countries
      end
    end
  end
end
