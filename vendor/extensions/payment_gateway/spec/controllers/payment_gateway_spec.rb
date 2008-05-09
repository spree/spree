require File.dirname(__FILE__) + '/../spec_helper'

describe Spree::BaseController do
  it "should include a payment gateway method" do
    controller.respond_to?(:payment_gateway).should be_true
  end
  
  it "should return an instance of Spree::BogusGateway in development mode" do
    ENV["RAILS_ENV"] = "development"
    controller.payment_gateway.should be_an_instance_of(Spree::BogusGateway)
  end
  
  it "should set the ActiveMerchant gateway mode to :test unless in production mode" do
    controller.payment_gateway.should be_test
  end  
end