require 'test_helper'

class CreditcardTest < ActiveSupport::TestCase
  fixtures :gateways
  
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
      @creditcard = Factory.build(:creditcard, :checkout => Factory(:checkout))
      @creditcard.authorize(100)
    end
    should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
  end
  
  context "authorization failure" do
    setup do
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999", :checkout => Factory(:checkout))
      begin @creditcard.authorize(100) rescue Spree::GatewayError end
    end
    should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('new').count") { Order.by_state('new').count }
  end

  context "purchase success" do
    setup do
      @creditcard = Factory.build(:creditcard, :checkout => Factory(:checkout))
      @order = @creditcard.checkout.order
      Factory(:line_item, :order => @order, :price => 100, :quantity => 1)
      @order.reload
      @order.save
      @creditcard.purchase(100)
    end
    should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
    context "followed by refund" do
      setup do
        @order.line_items.first.update_attribute(:price, 75)
        @order.reload
        @order.save
        
        @txn = @order.creditcard_payments.first.txns.first
        @creditcard.credit(25, @txn)
      end
      should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
      
      should "create a new payment with negative amount" do
        @new_transaction = @order.creditcard_payments.last.txns.first
        assert_equal -25.00, @new_transaction.amount
        assert_equal CreditcardTxn::TxnType::CREDIT, @new_transaction.txn_type
      end
 
    end
  end

  context "purchase failure" do
    setup do
      @creditcard = Factory.build(:creditcard, :number => "4111111111111999", :checkout => Factory(:checkout))
      begin @creditcard.purchase(100) rescue Spree::GatewayError end
    end
    should_not_change("CreditcardPayment.count") { CreditcardPayment.count }
    should_not_change("CreditcardTxn.count") { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
  end

end
