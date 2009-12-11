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
      should "not save number" do
        assert @creditcard.number
      end
      should "not save verification_value" do
        assert @creditcard.verification_value
      end
    end
    context "save (by default)" do
      setup do 
        @creditcard.save
      end
      should "not store number in memory" do
        assert !@creditcard.number
      end
      should "not store verification_value in memory" do
        assert !@creditcard.verification_value
      end
      should "not store number in database" do
        assert !@creditcard.reload.number
      end
      should "not store verification_value in database" do
        assert !@creditcard.reload.verification_value
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
      @creditcard.purchase(100)
    end
    should_change("CreditcardPayment.count", :by => 1) { CreditcardPayment.count }
    should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
    should_not_change("Order.by_state('paid').count") { Order.by_state('paid').count }
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
