require 'spec_helper'

describe Creditcard do

  before(:each) do
    @creditcard = Creditcard.new
    @payment = Payment.new(:amount => 100)

    @success_response = mock('gateway_response', :success? => true, :authorization => '123', :avs_result => {'code' => 'avs-code'})
    @fail_response = mock('gateway_response', :success? => false)

    @payment_gateway = mock('payment_gateway',
      :payment_profiles_supported? => true,
      :authorize => @success_response,
      :purchase => @success_response,
      :capture => @success_response,
      :void => @success_response,
      :credit => @success_response
    )

    @creditcard.stub!(:payment_gateway).and_return(@payment_gateway)

    @creditcard.stub!(:gateway_options).and_return({})
    @creditcard.stub!(:minimal_gateway_options).and_return({})
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
    it "should call purchase on the gateway with the payment amount" do
      @creditcard.payment_gateway.should_receive(:purchase).with(10000, @creditcard, {})
      @creditcard.purchase(100, @payment)
    end
    context "if sucessfull" do
      before do
        @payment_gateway.stub(:purchase).and_return(@success_response)
      end
      it "should store the response_code and avs_response" do
        @creditcard.purchase(100, @payment)
        @payment.response_code.should == '123'
        @payment.avs_response.should == 'avs-code'
      end
      it "should make payment complete" do
        @payment.should_receive(:complete)
        @creditcard.purchase(100, @payment)
      end
    end
    context "if unsucessfull" do
      it "should make payment failed" do
        @payment_gateway.stub(:purchase).and_return(@fail_response)
        @payment.should_receive(:fail)
        @payment.should_not_receive(:pend)
        lambda{
          @creditcard.purchase(100, @payment)
        }.should raise_error(Spree::GatewayError)
      end
    end
  end

  context "#capture" do
    before do
      @payment.stub(:complete).and_return(true)
    end
    context "when payment is pending" do
      before do
        @payment.state = 'pending'
      end
      it "should call capture on the gateway with the self as the authorization" do
        @creditcard.payment_gateway.should_receive(:capture).with(@payment, @creditcard, {})
        @creditcard.capture(@payment)
      end
      context "if sucessfull" do
        it "should make payment complete" do
          @payment.should_receive(:complete)
          @creditcard.capture(@payment)
        end
        it "should store the response_code" do
          @creditcard.capture(@payment)
          @payment.response_code.should == '123'
        end
      end
      context "if unsucessfull" do
        it "should not make payment complete" do
          @payment_gateway.stub(:capture).and_return(@fail_response)
          @payment.should_receive(:fail)
          @payment.should_not_receive(:complete)
          lambda{
            @creditcard.capture(@payment)
          }.should raise_error(Spree::GatewayError)
        end
      end
    end
    context "when payment is not pending" do
      before do
        @payment.state = 'checkout'
      end
      it "should not call capture on the gateway" do
        @creditcard.payment_gateway.should_not_receive(:capture).with(@payment, @creditcard, {})
        @creditcard.capture(@payment)
      end
    end
  end

  context "#void" do
    before do
      @payment.response_code = '123'
      @payment.state = 'pending'
    end
    it "should call payment_gateway.void with the payment's response_code" do
      @creditcard.payment_gateway.should_receive(:void).with('123', @creditcard, {})
      @creditcard.void(@payment)
    end
    context "if sucessfull" do
      it "should update the response_code with the authorization from the gateway" do
        @payment.response_code = 'abc'
        @creditcard.void(@payment)
        @payment.response_code.should == '123'
      end
      it "should void the payment" do
        @creditcard.should_receive(:void)
        @creditcard.void(@payment)
      end
    end
    context "if unsucesfull" do
      it "should not void the payment" do
        @payment_gateway.stub(:void).and_return(@fail_response)
        @payment.should_not_receive(:void)
        lambda {
          @creditcard.void(@payment)
        }.should raise_error(Spree::GatewayError)
      end
    end
  end

  context "#credit" do
    before do
      @payment.state = 'complete'
      @payment.response_code = '123'
    end
    it "should call credit on the gateway with the amount and response_code" do
      @creditcard.payment_gateway.should_receive(:credit).with(1000, @creditcard, '123', {})
      @creditcard.credit(@payment, 10)
    end
    context "when response is sucesssful" do
      it "should create an offsetting payment" do
        Payment.should_receive(:create)
        @creditcard.credit(@payment, 10)
      end
      context "resulting payment" do
        before do
          @offsetting_payment = @creditcard.credit(@payment, 10)
        end
        it "should be the supplied amount" do
          @offsetting_payment.amount.should == -10
        end
        it "should be in the complete state" do
          @offsetting_payment.should be_completed
        end
        it "has response_code from the transaction" do
          @offsetting_payment.response_code.should == '123'
        end
        it "has original payment as its source" do
          @offsetting_payment.source.should == @payment
        end
      end
    end
    context "when response is unsucessfull" do
      it "should not create a payment" do
        @payment_gateway.stub(:credit).and_return(@fail_response)
        Payment.should_not_receive(:create)
        lambda {
          @creditcard.credit(@payment, 10)
        }.should raise_error(Spree::GatewayError)
      end
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

  let(:creditcard) { Creditcard.new }

  context "#can_capture?" do
    it "should be true if payment state is pending" do
      payment = mock_model(Payment, :state => 'pending', :created_at => Time.now)
      creditcard.can_capture?(payment).should be_true
    end

    (PAYMENT_STATES - [PENDING]).each do |state|
      it "should be false if payment state is #{state}" do
        payment = mock_model(Payment, :state => state, :created_at => Time.now)
        creditcard.can_capture?(payment).should be_false
      end
    end
  end

  context "when transaction is more than 12 hours old" do
    let(:payment) { mock_model(Payment, :state => 'completed', :created_at => Time.now - 14.hours) }

    context "#can_credit?" do
      it "should be true if payment state is completed" do
        creditcard.can_credit?(payment).should be_true
      end

      (PAYMENT_STATES - [COMPLETED]).each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_credit?(payment).should be_false
        end
      end
    end

    context "#can_void?" do
      PAYMENT_STATES.each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_void?(payment).should be_false
        end
      end
    end
  end

  context "when transaction is less than 12 hours old" do
    let(:payment) { mock_model(Payment, :state => 'completed', :created_at => Time.now - 1.hour) }

    context "#can_credit?" do
      PAYMENT_STATES.each do |state|
        it "should be false if payment state is #{state}" do
          creditcard.can_credit?(payment).should be_false
        end
      end
    end

    context "#can_void?" do
      [PENDING, COMPLETED].each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_void?(payment).should be_true
        end
      end

      (PAYMENT_STATES - [PENDING, COMPLETED]).each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_void?(payment).should be_false
        end
      end
    end
  end

end

