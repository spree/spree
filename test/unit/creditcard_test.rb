require 'test_helper'

class CreditcardTest < ActiveSupport::TestCase
  fixtures :payment_methods
  
  context Creditcard do
    # NOTE: We want to test a real creditcard so we can't use the factory directly since it uses a hacked model to make 
    # testing easier.
    setup { @creditcard = Creditcard.new(Factory.attributes_for(:creditcard)) }
  
    context "save when configured to store credit card info" do
      setup do 
        Spree::Config.set(:store_cc => true, :store_cvv => true)
        @creditcard.save
      end
      should "save number" do
        assert @creditcard.reload.number
      end
      should "save verification_value" do
        assert @creditcard.reload.verification_value
      end
    end
    context "save (by default)" do
      setup do 
        @creditcard.save
      end
      should "store temporarily store number in memory" do
        assert @creditcard.number
      end
      should "store temporarily store verification_value in memory" do
        assert @creditcard.verification_value
      end
      should "not store number in database" do
        assert !@creditcard.reload.number
      end
      should "not store verification_value in database" do
        assert !@creditcard.reload.verification_value
      end
      should "store a masked version of the number" do
        assert @creditcard.reload.display_number.starts_with?("XXXX-XXXX-XXXX-")
      end
    end
  end
  
  context "authorization success" do
    setup do
      create_complete_order
      @payment = Factory(:payment)
      @creditcard = @payment.source
      @order.checkout.payments << @payment

      @creditcard.authorize(100)
      @authorization = @creditcard.authorization
    end
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
    should "store the avs_result" do
      assert_equal 'A', CreditcardTxn.first(:order => 'id DESC').avs_response
    end
    context "followed by capture" do
      setup do
        @creditcard.capture(@authorization)
      end
      should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      should "have authorization transaction assigned as original_txn on the new transaction" do
        assert_equal @authorization, @payment.creditcard_txns.first(:order => 'id DESC').original_txn
      end
      context "followed by void" do
        setup do
          @creditcard.void(@authorization)
        end
        #should_change("CreditcardPayment.count", :by => -1) { CreditcardPayment.count }
        should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      end
    end
    context "followed by void" do
      setup do
        @creditcard.void(@creditcard.authorization)
        @void_txn = @payment.creditcard_txns.first(:order => 'id DESC')
      end
      should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      should "create new transaction with correct attributes" do
        assert_equal CreditcardTxn::TxnType::VOID, @void_txn.txn_type
      end
    end
  end
  
  context "authorization failure" do
    setup do
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999")
      begin @creditcard.authorize(100) rescue Spree::GatewayError end
    end
    should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
  end
  
  context "purchase success" do
    setup do
      create_complete_order
      @payment = Factory(:payment)
      @creditcard = @payment.source
      @order.checkout.payments << @payment
      @creditcard.purchase(100)
    end
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
    context "followed by refund" do
      setup do
        @order.line_items.first.update_attribute(:price, 75)
        @order.reload
        @order.save
        @txn = @payment.creditcard_txns.first(:order => 'id DESC')
        @creditcard.credit(25, @txn)
      end
      should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      
      should "create a new payment with negative amount" do
        @new_transaction = @payment.creditcard_txns.first(:order => 'id DESC')
        assert_equal -25.00, @new_transaction.amount.to_f
        assert_equal CreditcardTxn::TxnType::CREDIT, @new_transaction.txn_type
      end
    end
  end
  
  context "purchase failure" do
    setup do
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999")
      begin @creditcard.purchase(100) rescue Spree::GatewayError end
    end
    should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
  end

end
