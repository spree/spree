require File.dirname(__FILE__) + '/../test_helper'

class OrderTest < Test::Unit::TestCase

  def test_empty_order
    order = Order.new
    assert !order.valid?
    assert order.errors.invalid?(:line_items)
  end
  
  def test_new_from_cart
    p = Product.new
    p.stubs(:price).returns(1)
    ci = CartItem.new(:product => p)
    c = Cart.new
    c.cart_items << ci
    li = LineItem.new
    li.stubs('quantity')
    li.stubs(:product).returns p
    
    LineItem.expects(:new).returns li
    order = Order.new_from_cart(c) 
    assert !order.nil?
    assert order.line_items.first == li
  end

  def test_new_from_cart_with_no_items
    c = Cart.new
    order = Order.new_from_cart(c) 
    assert order.nil?, "expected nil order with empty cart"
  end
  
  def test_generate_order_number
    on = Order.generate_order_number
    assert_not_nil on
    assert_equal 9, on.length
  end
  
  def test_item_total
    o = Order.new
    li = LineItem.new
    li.stubs(:total).returns(20)
    for num in (1..5)
      o.line_items << li  
    end
    assert_equal 100, o.item_total
  end
  
end
