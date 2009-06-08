require 'test_helper'

class CheckoutTest < ActiveSupport::TestCase
  fixtures :gateways, :gateway_configurations
  
  should_belong_to :bill_address
  should_belong_to :ship_address
  
  context "save" do 
    setup { @checkout = Factory(:incomplete_checkout) }
    context "with valid creditcard" do
      setup do
        @checkout.creditcard = Factory.attributes_for(:creditcard)                                           
        @checkout.save
      end
      should_change "Creditcard.count", :by => 1
      should_change "CreditcardPayment.count", :by => 1
      should_change "CreditcardTxn.count", :by => 1
    end   
    context "with invalid creditcard" do
      setup do
        @checkout.creditcard = {:number => "123"}
        @checkout.save
      end
      should_not_change "Creditcard.count"
      should_not_change "CreditcardPayment.count"
      should_not_change "CreditcardTxn.count"
    end  
    context "with an unauthorizable creditcard" do
      setup do
        @checkout.creditcard = Factory.attributes_for(:creditcard, :number => "4111111111111110")
        begin @checkout.save rescue Spree::GatewayError end
      end
      should_not_change "Creditcard.count"
      should_not_change "CreditcardPayment.count"
      should_not_change "CreditcardTxn.count"
    end  
  end
end
