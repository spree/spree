require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @order = Order.new
  end
  describe "save" do
    it "should not add the billing address if same as shipping" do
      ship_address = mock_model(Address)
      bill_address = ship_address
      addys = mock(Array)
      addys.should_not_receive(:<<)
      addys.should_not_receive(:push)
      user = mock_model(User, :addresses => addys)
      @order.save
    end
    it "should add the billing if user does not have same address already" do
      ship_address = mock_model(Address)
      bill_address = ship_address
      addys = []
      addys.stub!(:include?).with(bill_address).and_return(false)
      addys.should_receive(:<<).with(bill_address)
      #addys.should_not_receive(:push)
      user = mock_model(User, :addresses => addys)
      @order.bill_address = bill_address
      @order.ship_address = ship_address
      @order.save
    end    
  end
end