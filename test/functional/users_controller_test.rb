require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  context "on get to :show" do
    setup do
      @complete_checkout = Factory(:checkout) 
      @incomplete_checkout = Factory(:incomplete_checkout)      
      user = Factory(:user, :orders => [@complete_checkout.order, @incomplete_checkout.order])    
      @controller.stub!(:current_user, :return => user)
      get :show, :id => user.id
    end
    should_respond_with :success
    should_assign_to :orders
    context "@orders" do
      should "include complete orders" do 
        assert assigns(:orders).include?(@complete_checkout.order)
      end
      should "not include incomplete orders" do
        assert !assigns(:orders).include?(@incomplete_checkout.order)
      end
    end
  end
end