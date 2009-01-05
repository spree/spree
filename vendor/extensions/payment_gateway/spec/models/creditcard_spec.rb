require File.dirname(__FILE__) + '/../spec_helper'

describe CreditcardPayment do
  
  before(:each) do
    @creditcard = Creditcard.new
  end
  fixtures :gateways, :gateway_configurations

  describe "payment_gateway" do
    it "should exist" do
      @creditcard.respond_to?(:payment_gateway).should be_true
    end

    it "should return an instance of Spree::BogusGateway in development mode" do
      ENV["RAILS_ENV"] = "development"
      @creditcard.payment_gateway.should be_an_instance_of(Spree::BogusGateway)
    end

    it "should set the ActiveMerchant gateway mode to :test unless in production mode" do
      @creditcard.payment_gateway.should be_test
    end
  end
end