require File.dirname(__FILE__) + '/../test_helper'

class CreditcardWithAuthorizeNetCimTest < ActiveSupport::TestCase
  fixtures :gateways

  def setup
    Gateway.update_all(:active => false)
    @gateway = Gateway::AuthorizeNetCim.create!(:name => 'Authorize.net CIM Gateway', :environment => "test")
    @gateway.update_attribute(:active, true)
  end

  context "authorization success" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = false
      @creditcard = Factory.build(:creditcard)
      @checkout = Factory(:checkout)
      @payment = Factory(:payment, :source => @creditcard)
      @checkout.payments << @payment
      @order = @checkout.order

      Factory(:line_item, :variant => Factory(:variant), :order => @order, :price => 100.00, :quantity => 1)
      @order.reload
      @order.save
      
      @creditcard.authorize(100, @payment)
    end
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }

    should "setup save customer profile on card" do
      assert_equal "123", @creditcard.gateway_customer_profile_id
      assert_equal "456", @creditcard.gateway_payment_profile_id
      assert true
    end
    
    should "be able to capture the payment" do
      assert @creditcard.can_capture? @payment
    end
    
    context "followed by capture" do
      setup do
        @creditcard.capture(@payment)
      end
      should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    end
    
  end
  
  context "authorization failure" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = true
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999")
      @checkout = Factory(:checkout)
      begin
        @payment = Factory(:payment, :source => @creditcard)
        @checkout.payments << @payment
        @creditcard.authorize(100, @payment)
      rescue Spree::GatewayError
      end
    end
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
  end
  
  context "capture" do
    setup do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = false
      @creditcard = Factory.build(:creditcard)
      @checkout = Factory(:checkout)
      @payment = Factory(:payment, :source => @creditcard, :amount => @checkout.order.total)
      @checkout.payments << @payment
      @order = @checkout.order
      Factory(:line_item, :variant => Factory(:variant), :order => @order, :price => 100.00, :quantity => 1)
      @order.reload
      @order.save

      @creditcard.authorize(100, @payment)
      @creditcard.capture(@payment)
    end
    should "have 1 creditcard_payment with 2 transactions" do
      assert_equal 1, @creditcard.payments.count
      assert_equal 2, @payment.txns.count
    end
    should "have authorization transaction on the payment" do
      assert authorization = @creditcard.authorization(@payment)
      assert_equal '123456', authorization.response_code
      assert_equal 100, authorization.amount
    end
    should "not be able capture the payment again" do
      assert !@creditcard.can_capture?(@payment)
    end
    should "have capture transaction with correct amount" do
      txn = @payment.txns.first(:order => 'id DESC')
      assert_equal CreditcardTxn::TxnType::CAPTURE, txn.txn_type
      assert_equal 100, txn.amount
    end
  end
  
  context "purchase success" do
    setup do
      @creditcard = Factory.build(:creditcard)
      @checkout = Factory(:checkout)
      @payment = Factory(:payment, :source => @creditcard, :amount => @checkout.order.total)
      @checkout.payments << @payment
      @order = @checkout.order
      Factory(:line_item, :variant => Factory(:variant), :order => @order, :price => 100.00, :quantity => 1)
      @order.reload
      @order.save

      @creditcard.purchase(100, @payment)
    end
    should_change("Payment.count", :by => 1) { Payment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
  end

end
