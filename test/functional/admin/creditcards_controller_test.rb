require 'test_helper'

class Admin::CreditcardsControllerTest < ActionController::TestCase
  fixtures :gateways

  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      create_new_order
      @order.reload
      @creditcard = @order.creditcards.first      
    end

    context "GET index" do
      setup do
        get :index, :order_id => @order.id
      end
      should_assign_to :creditcards
      should_respond_with :success
    end
        
  end

end
