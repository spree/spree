require 'spec_helper'

describe Spree::Gateway::Braintree do

  before(:each) do
    Spree::Gateway.update_all :active => false
    @gateway = Spree::Gateway::Braintree.create!(:name => "Braintree Gateway", :environment => "test", :active => true)

    @gateway.set_preference(:merchant_id, "zbn5yzq9t7wmwx42" )
    @gateway.set_preference(:public_key, "ym9djwqpkxbv3xzt")
    @gateway.set_preference(:private_key, "4ghghkyp2yy6yqc8")
    @gateway.save!

    with_payment_profiles_off do
      @country = Factory(:country, :name => "United States", :iso_name => "UNITED STATES", :iso3 => "USA", :iso => "US", :numcode => 840)
      @state   = Factory(:state, :name => "Maryland", :abbr => "MD", :country => @country)
      @address = Factory(:address,
        :firstname => 'John',
        :lastname => 'Doe',
        :address1 => '1234 My Street',
        :address2 => 'Apt 1',
        :city =>  'Washington DC',
        :zipcode => '20123',
        :phone => '(555)555-5555',
        :state => @state,
        :country => @country
      )
      @order = Factory(:order_with_totals, :bill_address => @address, :ship_address => @address)
      @order.update!
      @creditcard = Factory(:creditcard, :verification_value => '123', :number => '5105105105105100', :month => 9, :year => Time.now.year + 1, :first_name => 'John', :last_name => 'Doe')
      @payment = Factory(:payment, :source => @creditcard, :order => @order, :payment_method => @gateway, :amount => @order.total)
    end

  end

  pending "should be braintree gateway" do
    @gateway.provider_class.should == ::ActiveMerchant::Billing::BraintreeGateway
  end

  pending "should be the Blue Braintree" do
    @gateway.provider.class.should == ::ActiveMerchant::Billing::BraintreeBlueGateway
  end

  describe "authorize" do
    pending "should return a success response with an authorization code" do
      result = @gateway.authorize(500, @creditcard,      {:server=>"test",
                                                        :test =>true,
                                                        :merchant_id=>"zbn5yzq9t7wmwx42",
                                                        :public_key=> "ym9djwqpkxbv3xzt",
                                                        :private_key=> "4ghghkyp2yy6yqc8"})



      result.success?.should be_true
      result.authorization.should match(/\A\w{6}\z/)


      Braintree::Transaction::Status::Authorized.should == Braintree::Transaction.find(result.authorization).status
   end

   pending 'should work through the spree payment interface' do
      Spree::Config.set :auto_capture => false
      @payment.log_entries.size.should == 0
      @payment.process!
      @payment.log_entries.size.should == 1
      @payment.response_code.should match /\A\w{6}\z/
      @payment.state.should == 'pending'
      transaction = ::Braintree::Transaction.find(@payment.response_code)
      transaction.status.should == Braintree::Transaction::Status::Authorized
      transaction.credit_card_details.masked_number.should == "510510******5100"
      transaction.credit_card_details.expiration_date.should == "09/#{Time.now.year + 1}"
      transaction.customer_details.first_name.should == 'John'
      transaction.customer_details.last_name.should == 'Doe'
   end

  end

  describe "capture" do

    pending " should capture a previous authorization" do
      @payment.process!
      assert_equal 1, @payment.log_entries.size
      assert_match /\A\w{6}\z/, @payment.response_code
      transaction = ::Braintree::Transaction.find(@payment.response_code)
      transaction.status.should == Braintree::Transaction::Status::Authorized
      capture_result = @gateway.capture(@payment,:ignored_arg_creditcard, :ignored_arg_options)
      capture_result.success?.should be_true
      transaction = ::Braintree::Transaction.find(@payment.response_code)
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    end

    pending "raise an error if capture fails using spree interface" do
      Spree::Config.set :auto_capture => false
      @payment.log_entries.size.should == 0
      @payment.process!
      @payment.log_entries.size.should == 1
      transaction = ::Braintree::Transaction.find(@payment.response_code)
      transaction.status.should == Braintree::Transaction::Status::Authorized
      @payment.payment_source.capture(@payment) # as done in PaymentsController#fire
      # transaction = ::Braintree::Transaction.find(@payment.response_code)
      # transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      # lambda do
      #   @payment.payment_source.capture(@payment)
      # end.should raise_error(Spree::Core::GatewayError, "Cannot submit for settlement unless status is authorized. (91507)")
    end
  end

  describe 'purchase' do
    pending 'should return a success response with an authorization code' do
      result =  @gateway.purchase(500, @creditcard)
      result.success?.should be_true
      result.authorization.should match(/\A\w{6}\z/)
      Braintree::Transaction::Status::SubmittedForSettlement.should == Braintree::Transaction.find(result.authorization).status
    end

    pending 'should work through the spree payment interface with payment profiles' do
      purchase_using_spree_interface
      transaction = ::Braintree::Transaction.find(@payment.response_code)
      transaction.credit_card_details.token.should_not be_nil
    end

    pending 'should work through the spree payment interface without payment profiles' do
        with_payment_profiles_off do
          purchase_using_spree_interface(false)
          transaction = ::Braintree::Transaction.find(@payment.response_code)
          transaction.credit_card_details.token.should be_nil
        end
    end
  end

  describe "credit" do
    pending "should work through the spree interface" do
      @payment.amount += 100.00
      purchase_using_spree_interface
      credit_using_spree_interface
    end
  end

  describe "void" do
    pending "should work through the spree creditcard / payment interface" do
      assert_equal 0, @payment.log_entries.size
      @payment.process!
      assert_equal 1, @payment.log_entries.size
      @payment.response_code.should match(/\A\w{6}\z/)
      transaction = Braintree::Transaction.find(@payment.response_code)
      transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
      @creditcard.void(@payment)
      transaction = Braintree::Transaction.find(transaction.id)
      transaction.status.should == Braintree::Transaction::Status::Voided
    end
  end
  def credit_using_spree_interface
    @payment.log_entries.size.should == 1
    @payment.source.credit(@payment) # as done in PaymentsController#fire
    @payment.log_entries.size.should == 2
    #Let's get the payment record associated with the credit
    @payment = @order.payments.last
    @payment.response_code.should match(/\A\w{6}\z/)
    transaction = ::Braintree::Transaction.find(@payment.response_code)
    transaction.type.should == Braintree::Transaction::Type::Credit
    transaction.status.should == Braintree::Transaction::Status::SubmittedForSettlement
    transaction.credit_card_details.masked_number.should == "510510******5100"
    transaction.credit_card_details.expiration_date.should == "09/#{Time.now.year + 1}"
    transaction.customer_details.first_name.should == "John"
    transaction.customer_details.last_name.should == "Doe"
  end

  def purchase_using_spree_interface(profile=true)
    Spree::Config.set :auto_capture => true
    @payment.send(:create_payment_profile) if profile
    @payment.log_entries.size == 0
    @payment.process! # as done in PaymentsController#create
    @payment.log_entries.size == 1
    @payment.response_code.should match /\A\w{6}\z/
    @payment.state.should == 'completed'
    transaction = ::Braintree::Transaction.find(@payment.response_code)
    Braintree::Transaction::Status::SubmittedForSettlement.should == transaction.status
    transaction.credit_card_details.masked_number.should == "510510******5100"
    transaction.credit_card_details.expiration_date.should == "09/#{Time.now.year + 1}"
    transaction.customer_details.first_name.should == 'John'
    transaction.customer_details.last_name.should == 'Doe'
  end

  def with_payment_profiles_off(&block)
    Spree::Gateway::Braintree.class_eval do
      def payment_profiles_supported?
        false
      end
    end
    yield
  ensure
    Spree::Gateway::Braintree.class_eval do
      def payment_profiles_supported?
        true
      end
    end
  end

end
