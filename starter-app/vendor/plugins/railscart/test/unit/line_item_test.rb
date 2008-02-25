require File.dirname(__FILE__) + '/../test_helper'

class LineItemTest < Test::Unit::TestCase
  
  PRICE = 10
  POS_PRICE_EFFECT = 5
  NEG_PRICE_EFFECT = -10
  QUANTITY = 2

  def setup
    @p = Product.new
    @p.stubs(:price).returns(PRICE)
  end
  
  def test_empty_line_item
    line_item = LineItem.new
    assert !line_item.valid?
    assert line_item.errors.invalid?(:product)
    assert line_item.errors.invalid?(:quantity)
    assert line_item.errors.invalid?(:price)
  end

  def test_from_cart_item
    ci = CartItem.new
    ci.expects(:quantity).returns(QUANTITY)
    ci.expects(:product).returns(@p).at_least_once
    li = LineItem.from_cart_item(ci)
    assert li.price == 10
    assert li.quantity == QUANTITY
    assert li.product == @p
  end

  def test_total
    li = LineItem.new
    li.product = @p
    li.quantity = 3
    li.price = PRICE
    assert_equal 3 * PRICE, li.total
  end

  def test_positive_price_variation
    v = Variation.new(:price_effect => POS_PRICE_EFFECT)
    ci = CartItem.new
    ci.stubs(:product).returns @p 
    ci.stubs(:variation).returns v
    ci.stubs(:quantity).returns QUANTITY
    li = LineItem.from_cart_item(ci)
    assert_equal li.price, PRICE + POS_PRICE_EFFECT
  end

  def test_negative_price_variation
    v = Variation.new(:price_effect => NEG_PRICE_EFFECT)
    ci = CartItem.new
    ci.stubs(:product).returns @p 
    ci.stubs(:variation).returns v
    ci.stubs(:quantity).returns QUANTITY
    li = LineItem.from_cart_item(ci)
    assert_equal li.price, PRICE + NEG_PRICE_EFFECT
  end

end
