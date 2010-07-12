require File.dirname(__FILE__) + '/../test_helper'
require "braintree"

class BraintreeTest < Test::Unit::TestCase

  def setup
    Gateway.update_all(:active => false)
    @gateway = Gateway::Braintree.create!(:name => "Braintree Gateway", :environment => "test", :active => true)

    # TODO: really need to figure out how preferences work in Spree
    #       doing configuration this way for now
    ::Braintree::Configuration.environment = :sandbox
    ::Braintree::Configuration.merchant_id = "zbn5yzq9t7wmwx42"
    ::Braintree::Configuration.public_key = "ym9djwqpkxbv3xzt"
    ::Braintree::Configuration.private_key = "4ghghkyp2yy6yqc8"
    ::Braintree::Configuration.class_eval do
      def self.merchant_id=(value); end
      def self.public_key=(value); end
      def self.private_key=(value); end
    end

    with_payment_profiles_off do
      @country = Factory(:country, :name => "United States", :iso_name => "UNITED STATES", :iso3 => "USA", :iso => "US", :numcode => 840)
      @address = Factory(:address,
        :firstname => 'John',
        :lastname => 'Doe',
        :address1 => '1234 My Street',
        :address2 => 'Apt 1',
        :city =>  'Washington DC',
        :zipcode => '20123',
        :phone => '(555)555-5555',
        :state_name => 'MD',
        :country => @country
      )
      @checkout = Factory(:checkout, :bill_address => @address, :ship_address => @address)
      @creditcard = Factory(:creditcard, :verification_value => '123', :number => '5105105105105100', :month => 9, :year => Time.now.year + 1, :first_name => 'John', :last_name => 'Doe')
      @payment = Factory(:payment, :source => @creditcard, :payable => @checkout, :amount => @checkout.order.total)
    end
  end

  context "provider_class" do
    should "be braintree gateway" do
      @gateway.provider_class.should == ::ActiveMerchant::Billing::BraintreeGateway
    end
  end

  context "authorize" do
    should "return a success response with an authorization code" do
      result = @gateway.authorize(500, @creditcard)
      assert_equal true, result.success?
      assert_match /\A\w{6}\z/, result.authorization
      assert_equal Braintree::Transaction::Status::Authorized, Braintree::Transaction.find(result.authorization).status
    end

    should "work through the spree payment interface" do
      Spree::Config.set :auto_capture => false
      assert_equal 0, @payment.txns.size
      @payment.process!
      assert_equal 1, @payment.txns.size
      assert_match /\A\w{6}\z/, @payment.txns[0].response_code
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::Authorized, transaction.status
      assert_equal "510510******5100", transaction.credit_card_details.masked_number
      assert_equal "09/#{Time.now.year + 1}", transaction.credit_card_details.expiration_date
      assert_equal "John", transaction.customer_details.first_name
      assert_equal "Doe", transaction.customer_details.last_name
    end
  end

  context "capture" do
    should "capture a previous authorization" do
      @payment.process!
      assert_equal 1, @payment.txns.size
      assert_match /\A\w{6}\z/, @payment.txns[0].response_code
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::Authorized, transaction.status
      capture_result = @gateway.capture(@payment.txns.first, :ignored_arg_creditcard, :ignored_arg_options)
      assert_equal true, capture_result.success?
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
    end

    should "raise an error if capture fails using spree interface" do
      Spree::Config.set :auto_capture => false
      assert_equal 0, @payment.txns.size
      @payment.process!
      assert_equal 1, @payment.txns.size
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::Authorized, transaction.status
      @payment.source.capture(@payment) # as done in PaymentsController#fire
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
      assert_raises(Spree::GatewayError, "Cannot submit for settlement unless status is authorized. (91507)") do
        @payment.source.capture(@payment) # as done in PaymentsController#fire
      end
    end

    should "work using the spree interface" do
      Spree::Config.set :auto_capture => false
      assert_equal 0, @payment.txns.size
      @payment.process!
      assert_equal 1, @payment.txns.size
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::Authorized, transaction.status
      @payment.source.capture(@payment) # as done in PaymentsController#fire
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
    end
  end

  context "purchase" do
    should "return a success response with an authorization code" do
      result = @gateway.purchase(500, @creditcard)
      assert_equal true, result.success?
      assert_match /\A\w{6}\z/, result.authorization
      assert_equal Braintree::Transaction::Status::SubmittedForSettlement, Braintree::Transaction.find(result.authorization).status
    end

    should "work through the spree payment interface with payment profiles" do
      purchase_using_spree_interface
      transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_match /\A\w{4}\z/, transaction.credit_card_details.token
    end

    should "work through the spree payment interface without payment profiles" do
      with_payment_profiles_off do
        purchase_using_spree_interface
        transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
        assert_equal nil, transaction.credit_card_details.token
      end
    end
  end

  context "credit" do
    should "work through the spree interface" do
      purchase_using_spree_interface
      credit_using_spree_interface
    end
  end

  context "void" do
    should "work through the spree creditcard / payment interface" do
      assert_equal 0, @payment.txns.size
      @payment.process!
      assert_equal 1, @payment.txns.size
      assert_match /\A\w{6}\z/, @payment.txns[0].response_code
      transaction = Braintree::Transaction.find(@payment.txns[0].response_code)
      assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
      @creditcard.void(@payment)
      transaction = Braintree::Transaction.find(transaction.id)
      assert_equal Braintree::Transaction::Status::Voided, transaction.status
    end
  end

  def credit_using_spree_interface
    @payment.order.payments << @payment
    assert_equal 1, @payment.txns.size
    @payment.source.credit(@payment) # as done in PaymentsController#fire
    assert_equal 2, @payment.txns.size
    assert_match /\A\w{6}\z/, @payment.txns[1].response_code
    transaction = ::Braintree::Transaction.find(@payment.txns[1].response_code)
    assert_equal Braintree::Transaction::Type::Credit, transaction.type
    assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
    assert_equal "510510******5100", transaction.credit_card_details.masked_number
    assert_equal "09/#{Time.now.year + 1}", transaction.credit_card_details.expiration_date
    assert_equal "John", transaction.customer_details.first_name
    assert_equal "Doe", transaction.customer_details.last_name
  end

  def purchase_using_spree_interface
    Spree::Config.set :auto_capture => true
    @payment.send(:create_payment_profile)
    assert_equal 0, @payment.txns.size
    @payment.process! # as done in PaymentsController#create
    assert_equal 1, @payment.txns.size
    assert_match /\A\w{6}\z/, @payment.txns[0].response_code
    transaction = ::Braintree::Transaction.find(@payment.txns[0].response_code)
    assert_equal Braintree::Transaction::Status::SubmittedForSettlement, transaction.status
    assert_equal "510510******5100", transaction.credit_card_details.masked_number
    assert_equal "09/#{Time.now.year + 1}", transaction.credit_card_details.expiration_date
    assert_equal "John", transaction.customer_details.first_name
    assert_equal "Doe", transaction.customer_details.last_name
  end

  def with_payment_profiles_off(&block)
    Gateway::Braintree.class_eval do
      def payment_profiles_supported?
        false
      end
    end
    yield
  ensure
    Gateway::Braintree.class_eval do
      def payment_profiles_supported?
        true
      end
    end
  end
end

