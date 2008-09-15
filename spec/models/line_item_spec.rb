require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LineItem do

  before(:each) do
    @line_item = LineItem.new
    @variant_proxy = mock_model(Variant, :on_hand => 45)
    @variant_proxy.stub!(:product).and_return(mock_model(Product, :name => 'Widget'))
    @line_item.stub!(:variant).and_return(@variant_proxy)
  end

  it "should only accept numeric quantity" do
    @line_item.quantity = "foo"
    @line_item.should_not be_valid
    @line_item.errors.should be_invalid(:quantity)
  end

  it "should require the quantity to be an integer" do
    @line_item.quantity = 0.5
    @line_item.should_not be_valid
    @line_item.errors.should be_invalid(:quantity)
  end

  it "should accept a valid quantity of 1" do
    @line_item.quantity = 1
    @line_item.price = 10
    @line_item.should be_valid
  end

  it "should not accept a quantity if there are none on hand" do
    @variant_proxy.should_receive(:on_hand).and_return(0)
    @line_item.quantity = 1
    @line_item.should_not be_valid
    @line_item.errors.should be_invalid(:quantity)
  end

  it "should not accept a quantity higher than stock on hand" do
    @line_item.quantity = @variant_proxy.on_hand + 99
    @line_item.should_not be_valid
    @line_item.errors.should be_invalid(:quantity)
  end

  it "should successfully increment the quantity" do
    @line_item.quantity = 1
    @line_item.increment_quantity
    @line_item.quantity.should == 2
  end

  it "should return the correct total" do
    @line_item.price = 2
    @line_item.quantity = 10
    @line_item.total.should == 20
  end

  
end
