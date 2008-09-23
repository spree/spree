require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LineItem do

  before(:each) do
    @variant = mock_model(Variant, :on_hand => 45)
    @variant.stub!(:product).and_return(mock_model(Product, :name => 'Widget'))
    @line_item = LineItem.new(:variant => @variant)
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

  describe "with :allow_backorders => false" do
    before(:each) do
      Spree::Config.stub!(:[]).with(:allow_backorders).and_return(false)
      @line_item.price = 10
    end
    it "should not accept a quantity if there are none on hand" do
      @variant.should_receive(:on_hand).and_return(0)
      @line_item.quantity = 1
      @line_item.should_not be_valid
      @line_item.errors.should be_invalid(:quantity)
    end

    it "should not accept a quantity higher than stock on hand" do
      @line_item.quantity = @variant.on_hand + 99
      @line_item.should_not be_valid
      @line_item.errors.should be_invalid(:quantity)
    end
  end

  describe "with :allow_backorders => true" do
    before(:each) do
      Spree::Config.stub!(:[]).with(:allow_backorders).and_return(true)
      @line_item.price = 10
    end
    it "should accept a quantity if there are none on hand" do
      @variant.should_receive(:on_hand).and_return(0)
      @line_item.quantity = 1
      @line_item.should be_valid
    end

    it "should accept a quantity higher than stock on hand" do
      @line_item.quantity = @variant.on_hand + 99
      @line_item.should be_valid
    end
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
