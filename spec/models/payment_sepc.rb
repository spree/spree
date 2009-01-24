require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Payment do
  before(:each) do
    @order = Order.new
    @order.checkout_complete = true
    @order.stub!(:total).and_return(100)
    @payment = CreditcardPayment.new(:order => @order)
  end

  describe "save hook" do
    it "should mark order as paid if payment_total = total" do
      @order.stub!(:payment_total).and_return(100)
      @order.should_receive(:pay!)
      @payment.save
    end
    it "should mark order as paid if payment_total > total" do
      @order.stub!(:payment_total).and_return(101)
      @order.should_receive(:pay!)
      @payment.save
    end
    it "should not mark order as paid if payment_total < total" do
      @order.stub!(:payment_total).and_return(99)
      @order.should_not_receive(:pay!)
      @payment.save
    end 
  end

end