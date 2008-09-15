require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @order = Order.new
    add_stubs(@order, :save => true)
  end

  describe "with address state" do
    before(:each) {@order.state = 'address'}
    describe "next" do
      it "should transition to credit_card_payment state" do
        @order.next
        @order.state.should == "creditcard_payment"
      end
      it "should calculate the tax during the transition" do
        @order.should_receive(:calculate_tax)
        @order.next
      end
    end
  end
end