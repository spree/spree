require 'test_helper'

class CheckoutTest < ActiveSupport::TestCase
  fixtures :gateways, :gateway_configurations
  
  should_belong_to :bill_address
  should_belong_to :ship_address

  context "incomplete checkout" do
    setup { @checkout = Factory(:incomplete_checkout) }
    context "with valid creditcard" do      
      setup { @checkout.creditcard = Factory.attributes_for(:creditcard) }                                           
      context "save with :auto_capture => false" do
        setup do
          @checkout.save
        end
        should_change "Creditcard.count", :by => 1
        should_change "CreditcardPayment.count", :by => 1
        should_change "CreditcardTxn.count", :by => 1
        should_change "@checkout.order.state", :from => 'in_progress', :to => 'new'
      end
      context "save with :auto_capture => true" do
        setup do
          Spree::Config.set(:auto_capture => true)
          @checkout.save
        end
        teardown { Spree::Config.set(:auto_capture => false) }
        should_change "Creditcard.count", :by => 1
        should_change "CreditcardPayment.count", :by => 1
        should_change "CreditcardTxn.count", :by => 1
        should_change "@checkout.order.state", :from => 'in_progress', :to => 'paid'
      end
    end
    context "save with declineable creditcard" do      
      setup do
        @checkout.creditcard = Factory.attributes_for(:creditcard, :number => "4111111111111110")
        begin @checkout.save rescue Spree::GatewayError end
      end
      should_not_change "Creditcard.count"
      should_not_change "CreditcardPayment.count"
      should_not_change "CreditcardTxn.count"          
      should_not_change "@checkout.order.state"
    end    
    context "with creditcard that fails validation" do
      setup do 
        @checkout.creditcard = {:number => "123"}
        @checkout.save
      end
      should_not_change "Creditcard.count"
      should_not_change "CreditcardPayment.count"
      should_not_change "CreditcardTxn.count"
    end
  end

  context "belonging to an order" do
    setup do 
      @checkout = Checkout.new(:order => Order.create, :ship_address => Factory(:address), :bill_address => Factory(:address))
    end
    context "with no shipping method" do
      setup { @checkout.save }
      should_not_change "@checkout.order.shipping_charges"
    end  
    context "with shipping method" do
      setup do
        @shipping_method = ShippingMethod.new  
        @checkout.shipping_method = @shipping_method
        @shipping_method.stub!(:available?, :return => true)
        @shipping_method.stub!(:calculate_shipping, :return => 10)
        @checkout.save 
      end
      should "increase shipping_charges by 1" do
        assert_equal 1, @checkout.order.shipping_charges.size
      end
      should "have the correct value for the new shipping charge" do
        assert_equal 10, @checkout.order.shipping_charges.first.amount
      end
      should_change "@checkout.order.total", :by => 10
      context "and shipping amount changes" do
        setup do
          @shipping_method.stub!(:calculate_shipping, :return => 20)
          @checkout.save
        end
        should_not_change "@checkout.order.shipping_charges.count"
        should_change "@checkout.order.shipping_charges.first.amount", :from => 10, :to => 20
      end      
    end 
    context "with taxable items" do
      setup do
        @checkout.order.stub!(:calculate_tax, :return => 15)
        @checkout.save
      end
      should "increase tax_charges by 1" do
        assert_equal 1, @checkout.order.tax_charges.size
      end
      should "have the correct value for the newly created tax charge" do
        assert_equal 15, @checkout.order.tax_charges.first.amount
      end
      should_change "@checkout.order.total", :by => 15
      context "and tax amount changes" do
        setup do
          @checkout.order.stub!(:calculate_tax, :return => 8)
          @checkout.save
        end
        should_not_change "@checkout.order.tax_charges.count"
        should_change "@checkout.order.tax_charges.first.amount", :from => 15, :to => 8
      end
    end 
    
  end
end
