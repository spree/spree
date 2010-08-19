require 'spec_helper'

describe Creditcard do

  let(:order) { mock_model(Order, :update! => nil) }
  # let(:payment) { Payment.new }
  
  before(:each) do
    @creditcard = mock_model(Creditcard, :save => true, :payment_gateway => nil)
    @payment = mock_model(Payment, :source => @creditcard)
  end

  context "#process!" do
    it "should purchase if with auto_capture"
    it "should authorize without auto_capture"
  end

  context "#authorize" do
    it "should call authorize on the gateway with the payment amount"
    context "if sucesssfull" do
      it "should store the response_code"
      it "should store the avs_response"
      it "should make payment pending"
    end
    context "if unsucessfull" do
      it "should make payment failed"
    end
  end

  context "#purchase" do
    it "should call purchase on the gateway with the payment amount"
    context "if sucessfull" do
      it "should store the response_code"
      it "should store the avs_response"
      it "should make payment complete"
    end
    context "if unsucessfull" do
      it "should make payment failed"
    end
  end

  context "#void" do
    it "should call payment_gateway.void with the payment's response_code"
    it "should update the response_code with the authorization from the gateway"
    it "should void the payment"
  end

  context "#credit" do
    context "if payment hasn't already been credited" do
      it "should call credit on the gateway with the amount and response_code"
      context "negative payment" do
        it "should be created if credit transaction is sucessfull"
        it "should have original payment amount but negative"
        it "should have the original payment as its source"
        it "should be complete"
      end
    end
    context "if payment already has been credited" do
      it "should not call credit on the gateway"
      it "should not create another payment"
    end
  end

end

