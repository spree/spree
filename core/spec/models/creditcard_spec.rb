require 'spec_helper'

describe Creditcard do

  before(:each) do
    @creditcard = Creditcard.new
    @payment = Payment.new(:amount => 100)

    @success_response = mock('gateway_response', :success? => true, :response_code => '123', :avs_result => {'code' => 'avs-code'})
    @fail_response = mock('gateway_response', :success? => false)

    @payment_gateway = mock('payment_gateway', :authorize => @success_response)


    @creditcard.stub!(:payment_gateway).and_return(@payment_gateway)
    # TODO: don't want to always stub this method since it should also be tested
    @creditcard.stub!(:gateway_options).and_return({})
  end

  context "#process!" do
    it "should purchase if with auto_capture" do
      Spree::Config.stub("[]").and_return(true)
      @creditcard.should_receive(:purchase)
      @creditcard.process!(@payment)
    end
    it "should authorize without auto_capture" do
      Spree::Config.stub("[]").and_return(false)
      @creditcard.should_receive(:authorize)
      @creditcard.process!(@payment)
    end
  end

  context "#authorize" do
    it "should call authorize on the gateway with the payment amount" do
      @creditcard.payment_gateway.should_receive(:authorize).with(10000, @creditcard, {})
      @creditcard.authorize(100, @payment) 
    end
    context "if sucesssfull" do
      it "should store the response_code and avs_response" do
        @creditcard.authorize(100, @payment) 
        @payment.response_code.should == '123'
        @payment.avs_response.should == 'avs-code'
      end
      it "should make payment pending" do
        @payment.should_receive(:pend)
        @creditcard.authorize(100, @payment) 
      end
    end
    context "if unsucessfull" do
      it "should make payment failed" do
        @payment_gateway.stub(:authorize).and_return(@fail_response)
        @payment.should_receive(:fail)
        @payment.should_not_receive(:pend)
        lambda{
          @creditcard.authorize(100, @payment) 
        }.should raise_error(Spree::GatewayError)
      end
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
    context "if sucessfull" do
      it "should update the response_code with the authorization from the gateway"
      it "should void the payment"
    end
    context "if unsucesfull" do
    end
  end

  context "#credit" do
    context "if payment hasn't already been credited" do
      it "should call credit on the gateway with the amount and response_code"
      context "when sucessfull" do
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

  context "#credit" do
    it "should call credit on the gateway with the amount and response_code"
    context "when response is sucesssful" do
      context "resulting payment" do
        it "should be the supplied amount"
        it "should be in the complete state"
        it "has response_code from the transaction"
        it "has original payment as its source"
      end
    end
    context "when response is unsucessfull" do
      it "should not create a payment"
    end
  end   

end

