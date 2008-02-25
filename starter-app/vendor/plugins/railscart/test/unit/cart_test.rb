require File.dirname(__FILE__) + '/../test_helper'

class CartTest < Test::Unit::TestCase
  
  def setup
    @cart = Cart.new
  end

  def test_add_product
    product = Product.new 
    @cart.add_product(product)
    cart_item = @cart.cart_items.first
    assert_equal product, cart_item.product, "expected same product after adding to cart"
    assert_equal 1, cart_item.quantity
  end

  def test_add_product_already_in_cart
    product = Product.new(:id => 1)
    product.expects(:increment_quantity).returns 2
    CartItem.expects(:find).returns product
    @cart.add_product(product)
  end
  
  def test_total
    item1 = CartItem.new
    item1.stubs(:price).returns 10
    item1.stubs(:quantity).returns 2
    item2 = CartItem.new
    item2.stubs(:price).returns 100
    item2.stubs(:quantity).returns 1
    @cart.cart_items << item1
    @cart.cart_items << item2
    assert_equal 120, @cart.total
  end
end
