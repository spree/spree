require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Cart do
  
  before(:each) do
    @cart = Cart.new
  end
  
  it "should be able to add a variant" do
    variant_proxy = mock_model(Variant)
    @cart.add_variant(variant_proxy)
    cart_item = @cart.cart_items.first
    cart_item.variant.should == variant_proxy
    cart_item.quantity.should == 1
  end

  it "should increment the quantity when variant is already in the cart" do
    ci_proxy = mock_model(CartItem)
    ci_proxy.should_receive(:increment_quantity).and_return(2)
    
    # use this stub to simulate the scenario where item is already in the cart (whic is stored in the database)
    CartItem.stub!(:find).and_return(ci_proxy)

    variant_proxy = mock_model(Variant)
    @cart.add_variant(variant_proxy)
  end
  
  it "should add the variant to the cart with the specified quantity" do
    variant_proxy = mock_model(Variant)
    @cart.add_variant(variant_proxy, 5)
    @cart.cart_items.first.quantity.should == 5
  end
  
  it "should return the correct cart item total" do
    v1_proxy = mock_model(Variant)
    p1_proxy = mock_model(Product)
    p1_proxy.stub!(:price).and_return(10)
    v1_proxy.stub!(:product).and_return(p1_proxy)
    
    v2_proxy = mock_model(Variant)
    p2_proxy = mock_model(Product)
    p2_proxy.stub!(:price).and_return(100)
    v2_proxy.stub!(:product).and_return(p2_proxy)
    
    @cart.add_variant(v1_proxy, 2)
    @cart.add_variant(v2_proxy)
    
    @cart.total.should == 120
  end
  
end