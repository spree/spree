require 'test_helper'

class CreditcardPaymentTest < ActiveSupport::TestCase
  fixtures :gateways, :gateway_configurations

  context "instance" do
    setup do
      @payment = Factory(:creditcard_payment)
      @auth_amount = @payment.authorization.amount
    end
    context "capture" do
      setup { @payment.capture }
      should_change "CreditcardTxn.count", :by => 1
      should "create a capture transaction" do
        assert_equal CreditcardTxn::TxnType::CAPTURE, CreditcardTxn.last.txn_type
      end
      should_change "@payment.amount", :from => 0, :to => @auth_amount
    end
    context "capture with no authorization" do
      setup do
        @payment.creditcard_txns = []
        @payment.capture
      end
      should_not_change "CreditcardTxn.count"
      should_not_change "@payment.amount"
    end
  end
end