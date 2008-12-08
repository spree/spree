require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Creditcard do
  it "should correctly assign the type of credit card based on the number" do
    am_creditcard = mock_model(ActiveMerchant::Billing::CreditCard, :null_object => true, :number => "4111111111111111")
    @creditcard = Creditcard.new_from_active_merchant(am_creditcard)
    @creditcard.cc_type.should == "visa"
  end
end
