require 'test_helper'                                    

class CheckoutTest < ActionController::IntegrationTest
  context "Checkout" do                                  
    setup do 
      @user = Factory(:admin_user, :password=>'test', :password_confirmation=>'test')
      @product = Factory(:product)
    end

    should "restore last not completed order, associated with user after log on, even if user start new order while was logged out." do
      get '/login'
      post_via_redirect '/user_sessions/create', {:user_session=>{:login=>@user.login, :password=>'test', :openid_identifier=>''}}
      assert_response :success
      assert_equal '/products', path

      #####
      # Create a new order while logged in
      #####
      post_via_redirect '/orders/create', {:variants=>{@product.master.id=>"1"}}
      assert_response :success
      first_order = Order.last
      assert_equal "/orders/#{first_order.number}/edit", path
      assert_equal @user.id, first_order.user_id

      get_via_redirect '/logout'
      assert_response :success
      assert_equal nil, response.session[:order_token]
      assert_equal nil, response.session[:order_id]
      
      #####
      # Create a new order while logged out
      #####
      post_via_redirect '/orders/create', {:variants=>{@product.master.id=>"1"}}      
      assert_response :success
      second_order = Order.last
      assert_equal "/orders/#{second_order.number}/edit", path

      get_via_redirect "/orders/#{second_order.number}/checkout/edit"
      assert_response :success
      assert_equal "/orders/#{second_order.number}/checkout/register", path

      #####
      # Login Again, as part of the checkout/register step
      #####
      get '/login'
      post_via_redirect '/user_sessions/create', {:user_session=>{:login=>@user.login, :password=>'test', :openid_identifier=>''}}
      assert_response :success
      #####
      # We are properly redirected to the first order
      #####
      assert_equal "/orders/#{first_order.number}/checkout/edit", path
      assert_equal first_order.token, response.session[:order_token]
      assert_equal first_order.id, response.session[:order_id]
      
      # line items from guest order should be added to restored uncompleted order
      assert_equal first_order.total + second_order.total, first_order.reload.total
    end
  end
end
