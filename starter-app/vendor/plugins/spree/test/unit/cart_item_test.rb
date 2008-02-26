require File.dirname(__FILE__) + '/../test_helper'

class CartItemTest < Test::Unit::TestCase
  fixtures :products

  PRICE = 10
  PRICE_EFFECT = 5
      
  def setup
    @cart_item = CartItem.new    
  end

  def test_invalid_with_empty_attributes
    assert !@cart_item.valid?
    assert @cart_item.errors.invalid?(:product), "product required"
    assert @cart_item.errors.invalid?(:quantity), "quantity required"
  end
  
  def test_invalid_quantity 
    @cart_item.quantity = "foo"
    @cart_item.product = products(:ror_tote)
    assert !@cart_item.valid?
    assert @cart_item.errors.invalid?(:quantity), "quantity must be numeric"

    @cart_item.quantity = 0.5
    assert !@cart_item.valid?
    assert @cart_item.errors.invalid?(:quantity), "quantity must be an integer"

    @cart_item.quantity = -1
    assert !@cart_item.valid?
    assert @cart_item.errors.invalid?(:quantity), "quantity must be positive"
  end
  
  def test_valid_quantity
    @cart_item.quantity = 1
    @cart_item.product = products(:ror_tote)
    assert @cart_item.valid?, "positive integer quantity should be allowed"
  end
  
  def test_increment_quantity
    @cart_item.quantity = 0
    @cart_item.increment_quantity
    assert_equal 1, @cart_item.quantity    
  end

  def test_price
    p = Product.new
    p.stubs(:price).returns PRICE
    p.stubs(:quantity).returns 1
    @cart_item.product = p
    @cart_item.variation = Variation.new(:price_effect => PRICE_EFFECT)  
    assert_equal PRICE + PRICE_EFFECT, @cart_item.price
  end
  
end
