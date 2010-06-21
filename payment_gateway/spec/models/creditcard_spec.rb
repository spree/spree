require File.dirname(__FILE__) + '/../spec_helper'

describe CreditcardPayment do
  
  before(:each) do
    @creditcard = Creditcard.new
  end
  fixtures :gateways

  describe "payment_gateway" do
    it "should exist" do
      @creditcard.respond_to?(:payment_gateway).should be_true
    end
  end
end