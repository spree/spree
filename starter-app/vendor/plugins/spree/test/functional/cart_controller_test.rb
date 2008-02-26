require File.dirname(__FILE__) + '/../test_helper'
require 'cart_controller'
#require 'product'

# Re-raise errors caught by the controller.
class CartController; def rescue_action(e) raise e end; end

class CartControllerTest < Test::Unit::TestCase
  def setup
    @controller = CartController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_add
    product = Product.new
    Product.expects(:find).with("1").returns product
    cart_item = CartItem.new
    cart_item.expects(:save)
    cart = mock()
    cart.expects(:add_product).with(product).returns cart_item
    cart.expects(:save)
    @request.session[:cart] = cart
    post :add, :id => 1
    assert_redirected_to :action => :index
  end

  def test_adding
    assert_difference(CartItem, :count) do
      post :add, :id => 4
    end
    
    assert_response :redirect
    assert_redirected_to :action => :index
    assert_equal 1, Cart.find(@request.session[:cart]).cart_items.size
  end
  
  def test_adding_with_javascript
    assert_difference(CartItem, :count) do
      xhr :post, :add, :id => 5
    end
    assert_response :success
    assert_equal 1, Cart.find(@request.session[:cart]).cart_items.size
  end
  
  def test_removing
    post :add, :id => 4
    assert_equal [Product.find(4)], Cart.find(@request.session[:cart]).products
    
    post :remove, :id => 4
    assert_equal [], Cart.find(@request.session[:cart]).products
  end
  
  def test_removing_with_javascript
    post :add, :id => 4
    assert_equal [Product.find(4)], Cart.find(@request.session[:cart]).products

    xhr :post, :remove, :id => 4
    assert_equal [], Cart.find(@request.session[:cart]).products
  end
  
  def test_clearing
    post :add, :id => 4
    post :empty
    assert_response :redirect
    assert_redirected_to :controller => :store, :action => :index
    assert_equal [], Cart.find(@request.session[:cart]).products
  end
  
  def test_clearing_with_javascript
    post :add, :id => 4
    xhr :post, :empty
    assert_response :success
    assert_equal 0, Cart.find(@request.session[:cart]).cart_items.size
  end
end