require File.dirname(__FILE__) + '/../spec_helper'

describe CreditcardPayment do
  
  before(:each) do
    @creditcard_payment = CreditcardPayment.new
  end
  fixtures :gateways, :gateway_configurations

  describe "payment_gateway" do
    it "should exist" do
      @creditcard_payment.respond_to?(:payment_gateway).should be_true
    end

    it "should return an instance of Spree::BogusGateway in development mode" do
      ENV["RAILS_ENV"] = "development"
      @creditcard_payment.payment_gateway.should be_an_instance_of(Spree::BogusGateway)
    end

    it "should set the ActiveMerchant gateway mode to :test unless in production mode" do
      @creditcard_payment.payment_gateway.should be_test
    end
  end
  
  describe "authorize_card" do
    it "should exist" do
      @creditcard_payment.respond_to?(:authorize_card).should be_true
    end
    
    it "should authorize the card for the amount of the order"
  end
end