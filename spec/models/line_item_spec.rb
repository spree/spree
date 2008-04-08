require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LineItem do

  before(:each) do
    @line_item = LineItem.new
  end

  it "should create the correct line item from the given cart item" do
    variant_proxy = mock_model(Variant)
    ci_proxy = mock_model(CartItem)
    ci_proxy.should_receive(:quantity).and_return(2)
    ci_proxy.should_receive(:variant).and_return(variant_proxy)
    ci_proxy.should_receive(:price).and_return(10)
    
    li = LineItem.from_cart_item(ci_proxy)
    li.price.should == 10
    li.quantity.should == 2
    li.variant.should == variant_proxy
  end
  
  it "should return the correct line item total" do
    variant_proxy = mock_model(Variant)
    ci_proxy = mock_model(CartItem)
    ci_proxy.should_receive(:quantity).and_return(3)
    ci_proxy.should_receive(:variant).and_return(variant_proxy)
    ci_proxy.should_receive(:price).and_return(10)

    li = LineItem.from_cart_item(ci_proxy)
    li.total.should == 30
  end
  
end