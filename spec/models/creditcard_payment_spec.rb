require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CreditcardPayment do
  before(:each) {@creditcard_payment = CreditcardPayment.create(:order => Order.new)}
  it "#can_capture? should return true if the last transaction was an authorization" do
    @creditcard_payment.txns.create(:txn_type => CreditcardTxn::TxnType::AUTHORIZE)
    @creditcard_payment.can_capture?.should == true
  end
  it "#can_capture? should return false if the last transaction is not an authorization" do
    @creditcard_payment.txns.create(:txn_type => CreditcardTxn::TxnType::CAPTURE)
    @creditcard_payment.can_capture?.should == false    
  end
end