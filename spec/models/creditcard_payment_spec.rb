require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CreditcardPayment do

  describe "new_from_active_merchant" do
    it "should correctly assign the type of credit card based on the number" do
      creditcard = mock_model(ActiveMerchant::Billing::CreditCard, :null_object => true, :number => "4111111111111111")
      creditcard_payment = CreditcardPayment.new_from_active_merchant(creditcard)
      creditcard_payment.cc_type.should == "visa"
    end
  end
end
