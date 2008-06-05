require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @bill_address = mock_model(Address)
    @ship_address = mock_model(Address)
    @user = mock_model(User, :addresses => [], :save! => nil)
    @order = Order.new(:ship_address => @ship_address, :bill_address => @bill_address, :user => @user)
    @order.stub!(:valid?).and_return(true)
  end
  
  describe "save" do
    it "should not add the billing address if same as shipping" do
      @user.should_receive(:add_address).with(@bill_address)
      @order.ship_address = @bill_address
      @order.save
    end

    it "should not add the billing address if user has it already" do
      @user.stub!(:addresses).and_return([@bill_address])
      @user.should_not_receive(:add_address).with(@bill_address)
      @user.should_receive(:add_address).with(@ship_address)
      @order.save
    end    

    it "should not add the shipping address if user has it already" do
      @user.stub!(:addresses).and_return([@ship_address])
      @user.should_not_receive(:add_address).with(@ship_address)
      @user.should_receive(:add_address).with(@bill_address)
      @order.save
    end    

  end
end