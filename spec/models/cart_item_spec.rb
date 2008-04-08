require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CartItem do
  
  before(:each) do
    @cart_item = CartItem.new
  end
  
  it "should only accept numeric quantity" do
    @cart_item.quantity = "foo"
    @cart_item.should_not be_valid
    @cart_item.errors.should be_invalid(:quantity)
  end
  
  it "should require the quantity to be an integer" do
    @cart_item.quantity = 0.5
    @cart_item.should_not be_valid
    @cart_item.errors.should be_invalid(:quantity)
  end

  it "should require the quantity to be positive" do
    @cart_item.quantity = -1
    @cart_item.should_not be_valid
    @cart_item.errors.should be_invalid(:quantity)
  end
  
  it "should accept a valid quantity of 1" do
    @cart_item.quantity = 1
    variant_proxy = mock_model(Variant)
    @cart_item.stub!(:variant).and_return(variant_proxy)
    @cart_item.should be_valid
  end
  
  it "should successfully increment the quantity" do
    @cart_item.quantity = 1
    @cart_item.increment_quantity
    @cart_item.quantity.should == 2
  end

  # TODO - consider testing the price effect if we decide to keep this (see the old unit test below )
  #def test_price
  #  p = Product.new
  #  p.stubs(:price).returns PRICE
  #  p.stubs(:quantity).returns 1
  #  @cart_item.product = p
  #  @cart_item.variation = Variation.new(:price_effect => PRICE_EFFECT)  
  #  assert_equal PRICE + PRICE_EFFECT, @cart_item.price
  #end
  
end