require 'spec_helper'

describe Spree::Creditcard do

  context 'validation' do
    it { should have_valid_factory(:creditcard) }
  end

  let(:valid_creditcard_attributes) { {:number => '4111111111111111', :verification_value => '123', :month => 12, :year => 2014} }

  def stub_rails_env(environment)
    Rails.stub(:env => ActiveSupport::StringInquirer.new(environment))
  end

  before(:each) do

    @order = Factory(:order)
    @creditcard = Spree::Creditcard.new
    @payment = Spree::Payment.create({:amount => 100, :order => @order}, :without_protection => true)

    @success_response = mock('gateway_response', :success? => true, :authorization => '123', :avs_result => {'code' => 'avs-code'})
    @fail_response = mock('gateway_response', :success? => false)

    @payment_gateway = mock_model(Spree::PaymentMethod,
      :payment_profiles_supported? => true,
      :authorize => @success_response,
      :purchase => @success_response,
      :capture => @success_response,
      :void => @success_response,
      :credit => @success_response,
      :environment => 'test'
    )

    @payment.stub :payment_method => @payment_gateway
  end

  context "#process!" do
    it "should purchase if with auto_capture" do
      Spree::Config[:auto_capture] = true
      @creditcard.should_receive(:purchase)
      @creditcard.process!(@payment)
    end
    it "should authorize without auto_capture" do
      Spree::Config[:auto_capture] = false
      @creditcard.should_receive(:authorize)
      @creditcard.process!(@payment)
    end
  end

  context "#authorize" do
    it "should call authorize on the gateway with the payment amount" do
      @payment_gateway.should_receive(:authorize).with(10000, @creditcard, anything)
      @creditcard.authorize(100, @payment)
    end

    it "should log the response" do
      @payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
      @creditcard.authorize(100, @payment)
    end

    context "when gateway does not match the environment" do
      it "should raise an exception" do
        @payment_gateway.stub :environment => "foo"
        lambda {@creditcard.authorize(100, @payment)}.should raise_error(Spree::Core::GatewayError)
      end
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
        @payment.should_receive(:failure)
        @payment.should_not_receive(:pend)
        lambda{
          @creditcard.authorize(100, @payment)
        }.should raise_error(Spree::Core::GatewayError)
      end
    end
  end

  context "#purchase" do
    it "should call purchase on the gateway with the payment amount" do
     @payment_gateway.should_receive(:purchase).with(10000, @creditcard, anything)
     @creditcard.purchase(100, @payment)
    end
    it "should log the response" do
     @payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
     @creditcard.purchase(100, @payment)
    end
    context "when gateway does not match the environment" do
     it "should raise an exception" do
       @payment_gateway.stub :environment => "foo"
       lambda {@creditcard.purchase(100, @payment)}.should raise_error(Spree::Core::GatewayError)
     end
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
       @payment.should_receive(:failure)
       @payment.should_not_receive(:pend)
       lambda{
         @creditcard.purchase(100, @payment)
       }.should raise_error(Spree::Core::GatewayError)
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
        @payment_gateway.should_receive(:capture).with(@payment, @creditcard, anything)
        @creditcard.capture(@payment)
      end
      it "should not pass subtotal" do
        @order.stub :item_total => 90
        @payment_gateway.should_not_receive(:capture).with(@payment, @creditcard,
                                                           hash_including(:subtotal => 9000))
        @creditcard.capture(@payment)
      end
      it "should not pass shipping" do
        @order.stub :ship_total => 5
        @payment_gateway.should_not_receive(:capture).with(@payment, @creditcard,
                                                           hash_including(:shipping => 500))
        @creditcard.capture(@payment)
      end
      it "should not pass tax" do
        @order.stub :tax_total => 5
        @payment_gateway.should_not_receive(:capture).with(@payment, @creditcard,
                                                           hash_including(:tax=> 500))
        @creditcard.capture(@payment)
      end
      it "should log the response" do
        @payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
        @creditcard.capture(@payment)
      end
      context "when gateway does not match the environment" do
       it "should raise an exception" do
         @payment_gateway.stub :environment => "foo"
         lambda {@creditcard.capture(@payment)}.should raise_error(Spree::Core::GatewayError)
       end
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
         @payment.should_receive(:failure)
         @payment.should_not_receive(:complete)
         lambda{
           @creditcard.capture(@payment)
         }.should raise_error(Spree::Core::GatewayError)
       end
      end
    end
    context "when payment is not pending" do
      before do
        @payment.state = 'checkout'
      end
      it "should not call capture on the gateway" do
        @payment_gateway.should_not_receive(:capture).with(@payment, @creditcard, anything)
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
      @payment_gateway.should_receive(:void).with('123', anything)
      @creditcard.void(@payment)
    end
    it "should not pass subtotal" do
      @order.stub :item_total => 90
      @payment_gateway.should_not_receive(:void).with('123', hash_including(:subtotal => 9000))
      @creditcard.void(@payment)
    end
    it "should not pass shipping" do
      @order.stub :ship_total => 5
      @payment_gateway.should_not_receive(:void).with('123', hash_including(:shipping => 500))
      @creditcard.void(@payment)
    end
    it "should not pass tax" do
      @order.stub :tax_total => 5
      @payment_gateway.should_not_receive(:void).with('123', hash_including(:tax=> 500))
      @creditcard.void(@payment)
    end
    it "should log the response" do
      @payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
      @creditcard.void(@payment)
    end
    context "when gateway does not match the environment" do
      it "should raise an exception" do
        @payment_gateway.stub :environment => "foo"
        lambda {@creditcard.void(@payment)}.should raise_error(Spree::Core::GatewayError)
      end
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
        }.should raise_error(Spree::Core::GatewayError)
      end
    end
  end

  context "#credit" do
    before do
      @payment.state = 'complete'
      @payment.response_code = '123'
      @payment.stub(:order).and_return(@order)
    end

    context "when outstanding_balance is less than payment amount" do
      before {  @order.stub :outstanding_balance => 10 }

      it "should call credit on the gateway with the credit amount and response_code" do
        @payment_gateway.should_receive(:credit).with(1000, @creditcard, '123', anything)
        @creditcard.credit(@payment)
      end
      it "should not pass subtotal" do
        @order.stub :item_total => 90
        @payment_gateway.should_not_receive(:credit).with(1000, @creditcard, '123',
                                                          hash_including(:subtotal => 9000))
        @creditcard.credit(@payment)
      end
      it "should not pass shipping" do
        @order.stub :ship_total => 5
        @payment_gateway.should_not_receive(:credit).with(1000, @creditcard, '123',
                                                          hash_including(:shipping => 500))
        @creditcard.credit(@payment)
      end
      it "should not pass tax" do
        @order.stub :tax_total => 5
        @payment_gateway.should_not_receive(:credit).with(1000, @creditcard, '123',
                                                          hash_including(:tax => 500))
        @creditcard.credit(@payment)
      end
    end

    context "when outstanding_balance is equal to payment amount" do
      before { @order.stub :outstanding_balance => 100 }

      it "should call credit on the gateway with the credit amount and response_code" do
        @payment_gateway.should_receive(:credit).with(10000, @creditcard, '123', anything)
        @creditcard.credit(@payment)
      end
    end

    context "when outstanding_balance is greater than payment amount" do
      before {  @order.stub :outstanding_balance => 101 }

      it "should call credit on the gateway with the original payment amount and response_code" do
        @payment_gateway.should_receive(:credit).with(10000, @creditcard, '123', anything)
        @creditcard.credit(@payment)
      end
    end

    it "should log the response" do
      @payment.log_entries.should_receive(:create).with({:details => anything}, {:without_protection => true})
      @creditcard.credit(@payment)
    end

    context "when gateway does not match the environment" do
      it "should raise an exception" do
        @payment_gateway.stub :environment => "foo"
        lambda {@creditcard.credit(@payment)}.should raise_error(Spree::Core::GatewayError)
      end
    end

    context "when response is sucesssful" do
      it "should create an offsetting payment" do
        Spree::Payment.should_receive(:create)
        @creditcard.credit(@payment)
      end
      context "resulting payment" do
        before do
          @order.stub :outstanding_balance => 10
          @offsetting_payment = @creditcard.credit(@payment)
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
        Spree::Payment.should_not_receive(:create)
        lambda {
          @creditcard.credit(@payment)
        }.should raise_error(Spree::Core::GatewayError)
      end
    end
  end

  let(:creditcard) { Spree::Creditcard.new }

  context "#can_capture?" do
    it "should be true if payment state is pending" do
      payment = mock_model(Spree::Payment, :state => 'pending', :created_at => Time.now)
      creditcard.can_capture?(payment).should be_true
    end

    (PAYMENT_STATES - ['pending']).each do |state|
      it "should be false if payment state is #{state}" do
        payment = mock_model(Spree::Payment, :state => state, :created_at => Time.now)
        creditcard.can_capture?(payment).should be_false
      end
    end
  end

  context "when transaction is more than 12 hours old" do
    let(:payment) { mock_model(Spree::Payment, :state => "completed",
                                               :created_at => Time.now - 14.hours,
                                               :amount => 99.00,
                                               :credit_allowed => 100.00,
                                               :order => mock_model(Spree::Order, :payment_state => 'credit_owed')) }

    context "#can_credit?" do

      it "should be true when payment state is 'completed' and order payment_state is 'credit_owed' and credit_allowed is greater than amount" do
        creditcard.can_credit?(payment).should be_true
      end

      it "should be false when order payment_state is not 'credit_owed'" do
        payment.order.stub(:payment_state => 'paid')
        creditcard.can_credit?(payment).should be_false
      end

      it "should be false when credit_allowed is zero" do
        payment.stub(:credit_allowed => 0)
        creditcard.can_credit?(payment).should be_false
      end

      (PAYMENT_STATES - ['completed']).each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_credit?(payment).should be_false
        end
      end

    end

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          payment.stub :void? => false
          creditcard.can_void?(payment).should be_true
        end
      end

      it "should be valse if payment state is void" do
        payment.stub :state => 'void'
        creditcard.can_void?(payment).should be_false
      end
    end
  end

  context "when transaction is less than 12 hours old" do
    let(:payment) { mock_model(Spree::Payment, :state => 'completed') }

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_void?(payment).should be_true
        end
      end

      it "should be false if payment state is void" do
        payment.stub :state => 'void'
        creditcard.can_void?(payment).should be_false
      end

    end
  end

  context "#valid?" do
    it "should validate presence of number" do
      @creditcard.attributes = valid_creditcard_attributes.except(:number)
      @creditcard.should_not be_valid
      @creditcard.errors[:number].should == ["can't be blank"]
    end

    it "should validate presence of security code" do
      @creditcard.attributes = valid_creditcard_attributes.except(:verification_value)
      @creditcard.should_not be_valid
      @creditcard.errors[:verification_value].should == ["can't be blank"]
    end

    it "should only validate on create" do
      @creditcard.attributes = valid_creditcard_attributes
      @creditcard.save
      @creditcard = Spree::Creditcard.find(@creditcard.id)
      @creditcard.should be_valid
    end
  end

  context "#save" do
    before do
      @creditcard.attributes = valid_creditcard_attributes
      @creditcard.save
      @creditcard = Spree::Creditcard.find(@creditcard.id)
    end

    it "should not actually store the number" do
      @creditcard.number.should be_blank
    end

    it "should not actually store the security code"  do
      @creditcard.verification_value.should be_blank
    end
  end

  context "#spree_cc_type" do
    before do
      @creditcard.attributes = valid_creditcard_attributes
    end

    context "in development mode" do
      before do
        stub_rails_env("production")
      end

      it "should return visa" do
        @creditcard.save
        @creditcard.spree_cc_type.should == "visa"
      end
    end

    context "in production mode" do
      before do
        stub_rails_env("production")
      end

      it "should return the actual cc_type for a valid number" do
        @creditcard.number = "378282246310005"
        @creditcard.save
        @creditcard.spree_cc_type.should == "american_express"
      end
    end
  end

  context "#set_card_type" do
    before :each do
      stub_rails_env("production")
      @creditcard.attributes = valid_creditcard_attributes
    end

    it "stores the creditcard type after validation" do
      @creditcard.number = "6011000990139424"
      @creditcard.save
      @creditcard.spree_cc_type.should == "discover"
    end

    it "does not overwrite the creditcard type when loaded and saved" do
      @creditcard.number = "5105105105105100"
      @creditcard.save
      @creditcard.number = "XXXXXXXXXXXX5100"
      @creditcard.save
      @creditcard.spree_cc_type.should == "master"
    end
  end
end

