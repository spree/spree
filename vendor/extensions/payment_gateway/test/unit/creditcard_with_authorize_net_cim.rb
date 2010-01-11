require File.dirname(__FILE__) + '/../test_helper'

class ShipmentsApiTest < ActiveSupport::TestCase
  fixtures :gateways

  def setup
    Gateway.update_all(:active => false)
    @gateway = gateways(:authorize_net_cim_test)
    @gateway.update_attribute(:active, true)
  end

  context "authorization success" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = false
      @creditcard = Factory.build(:creditcard, :checkout => Factory(:checkout))
      @creditcard.authorize(100)
    end
    should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }

    should "setup save customer profile on card" do
      assert_equal "123", @creditcard.gateway_customer_profile_id
      assert_equal "456", @creditcard.gateway_payment_profile_id
      assert true
    end
    
    should "be able to capture the payment" do
      assert @creditcard.creditcard_payments.first.can_capture?
    end
  end
  
  context "authorization failure" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = true
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999", :checkout => Factory(:checkout))
      begin @creditcard.authorize(100) rescue Spree::GatewayError end
    end
    should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
  end

  context "capture" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = false
      @creditcard = Factory.build(:creditcard, :checkout => Factory(:checkout))
      @creditcard.authorize(100)
      @creditcard.creditcard_payments.first.capture
    end
    should "have 1 creditcard_payment with 2 transactions" do
      assert_equal 1, @creditcard.creditcard_payments.count
      assert_equal 2, @creditcard.creditcard_payments.first.txns.count
    end
    should "have authorization transaction on the payment" do
      assert authorization = @creditcard.creditcard_payments.first.authorization
      assert_equal 'XYZ', authorization.response_code
      assert_equal 100, authorization.amount
    end
    should "not be able capture the payment again" do
      assert !@creditcard.creditcard_payments.first.can_capture? 
    end
    should "have capture transaction with correct amount" do
      txn = @creditcard.creditcard_payments.first.txns.last
      assert_equal CreditcardTxn::TxnType::CAPTURE, txn.txn_type
      assert_equal 100, txn.amount
    end
  end

  context "purchase success" do
    setup do
      @creditcard = Factory.build(:creditcard, :checkout => Factory(:checkout))
      @creditcard.purchase(100)
    end
    should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
  end

end