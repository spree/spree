require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @creditcard_payment = mock_model(CreditcardPayment, :null_object => true)
    @order = Order.new(:creditcard_payment => @creditcard_payment)
    add_stubs(@order, :save => true)
  end

  describe "capture" do
    it "should capture the creditcard_payment" do
      @order.state = 'authorized'
      @creditcard_payment.should_receive(:capture)
      @order.capture
    end
  end

  describe "cancel" do
    %w{authorized captured}.each do |state|
      describe "from #{state} state" do
        it "should cancel the creditcard_payment" do
          @order.state = state
          @creditcard_payment.should_receive(:void)
          @order.cancel
        end
      end
    end
  end

end