require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @variant = mock_model(Variant)
    @inventory_unit = mock_model(InventoryUnit, :null_object => true)
    @creditcard_payment = mock_model(CreditcardPayment, :null_object => true)
    @user = mock_model(User, :email => "foo@exampl.com")
    @order = Order.new(:checkout_complete => true, :creditcard_payment => @creditcard_payment, :number => '#TEST1010', :user => @user)
    add_stubs(@order, :save => true, :inventory_units => [@inventory_unit])
    @order.line_items << (mock_model(LineItem, :variant => @variant, :quantity => 1))
    InventoryUnit.stub!(:retrieve_on_hand).with(@variant, 1).and_return [@inventory_unit]
    OrderMailer.stub!(:deliver_confirm).with(any_args)   
    OrderMailer.stub!(:deliver_cancel).with(any_args)    
  end

  describe "create" do
    it "should generate an order number"
  end
  
  describe "next" do
    describe "from creditcard_payment" do
      before(:each) do
        @order.state = 'creditcard_payment'
      end
      it "should transition to authorized" do
        @order.next
        @order.state.should == "authorized"
      end
      it "should mark inventory as sold" do
        @inventory_unit.should_receive(:sell!)
        @order.next
      end
      it "should send a confirmation email" do
        OrderMailer.should_receive(:deliver_confirm).with(@order)
        @order.next
      end
    end
  end
  
  describe "pay" do
    it "should mark inventory as sold" do
      @order.state = "pending_payment"
      @inventory_unit.should_receive(:sell!)
      @order.pay
    end
  end
  
  describe "ship" do
    before(:each) {@order.state = "captured"}
    it "should transition to shipped" do
      @order.ship
      @order.state.should == 'shipped'
    end
    it "should mark inventory as shipped" do
      @inventory_unit.should_receive(:ship!)
      @order.ship
    end
  end
  
  describe "cancel" do
    it "should mark inventory as on_hand" do
      @order.state = "captured"
      @inventory_unit.stub!(:state).and_return('sold')
      @inventory_unit.should_receive(:restock!)
      @order.cancel
    end
    it "should send a cancellation email" do
      OrderMailer.should_receive(:deliver_cancel).with(@order)
      @order.cancel
    end
  end
  
  describe "return" do
    it "should mark inventory as on_hand" do
      @order.state = "shipped"
      @inventory_unit.stub!(:state).and_return('shipped')
      @inventory_unit.should_receive(:restock!)
      @order.return
    end
  end
  
end