require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  context "on get to :show" do
    setup do
      user = Factory(:user)
      @completed_order = Factory(:order, :user => user)
      @incomplete_order = Factory(:order, :user => user)
      @completed_order.send(:complete_order)

      @controller.stub!(:current_user, :return => user)
      get :show, :id => user.id
    end
    should_respond_with :success
    should_assign_to :orders
    context "@orders" do
      should "include complete orders" do
        assert assigns(:orders).include?(@completed_order)
      end
      should "not include incomplete orders" do
        assert !assigns(:orders).include?(@incomplete_order)
      end
    end
  end
end