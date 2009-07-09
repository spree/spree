require 'test_helper'

class CheckoutsControllerTest < ActionController::TestCase
  fixtures :countries, :states, :gateways, :gateway_configurations
  
  context "given current_user" do
    setup do 
      @user = Factory(:user, :email => "test@example.com")
      @controller.stub!(:current_user, :return => @user)
      @order = Factory.create(:order)
      @params = { :order_id => @order.number }
      session[:order_id] = @order.id
      @address = Factory.build(:address)
      @creditcard = Factory.build(:creditcard)
    end
    context "post" do
      setup do
        @params = { :final_answer => true, :order_id => @order.number }
        @shipping_method = Factory(:shipping_method)               
        @params[:final_answer] = true
        @params[:checkout] = {:bill_address_attributes => @address.attributes.symbolize_keys,
                              :ship_address_attributes => @address.attributes.symbolize_keys,
                              :shipping_method_id => @shipping_method.id,
                              :creditcard => @creditcard.attributes.symbolize_keys}
        post :update 
      end
      should_change "Address.count", :by => 2
      should_redirect_to("order completion page") { order_url(@order, :checkout_complete => true) }    
      should "assign the current_user email" do
        assert_equal "test@example.com", assigns(:checkout).email
      end
      should "assign the requestor IP" do
        assert_equal "0.0.0.0", assigns(:checkout).ip_address
      end
      should "assign the requested shipping method" do
        assert_equal @shipping_method, assigns(:checkout).shipping_method
      end
      should "remove the order_id from the session" do
        assert_equal nil, session[:order_id]
      end 
    end
    context "xhr put" do
      setup { xhr :put, :update }
      should_respond_with :success
    end  

    context "xhr put with valid coupon code" do
      setup do
        @coupon = Factory(:coupon, :code => "FOO") 
        xhr :put, :update, :checkout => { :coupon_code => "FOO" }, :order_id => @order.id
      end
      should_change "@order.credits.count", :by => 1
    end

    context "xhr put with invalid coupon code" do
      setup { xhr :put, :update, :coupon_code => "BOGUS", :order_id => @order.id }
      should_respond_with :success
      should_not_change "@order.credits.count"
    end
    
    context "xhr put with bill and ship address" do
      setup do 
        xhr :put, :update, :bill_address_attributes => Factory.build(:address).attributes.symbolize_keys,
                           :ship_address_attributes => Factory.build(:address).attributes.symbolize_keys
      end
      should_respond_with :success
    end  
  end
end
