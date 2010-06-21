require 'test_helper'

class CheckoutsControllerTest < ActionController::TestCase
  fixtures :countries, :states, :gateways
                
  context "current_user" do
    setup do 
      set_current_user
      Spree::Config.set({ :default_country_id => countries(:united_states).id })
    end
    context "with incomplete order" do
      setup do 
        @order = Factory(:order)
        @params = { :order_id => @order.number, :order_token => @order.token } 
      end
      context "GET /show" do
        setup { get :show } 
        should_redirect_to_first_step
      end
      context "GET /edit" do
        setup { get :edit } 
        should "assign the checkout ip address" do
          assert_equal "0.0.0.0", assigns(:checkout).ip_address
        end
        should_render_template :edit
      end
      context "without an order token" do
        setup do
          @params = { :order_id => @order.number, :order_token => nil } 
          get :edit
        end
        should_redirect_to_authorization_failure
      end
    end
    context "complete order" do
      setup do 
        @order = create_complete_order
        @order.complete
        @params = { :order_id => @order.number, :order_token => @order.token } 
      end
      context "GET /checkout" do
        setup { get :show } 
        should_redirect_to_thanks
      end    
      context "GET /checkout/edit" do
        setup { get :edit } 
        should_redirect_to_thanks
      end    
      context "PUT /checkout" do
        setup { post :update } 
        should_redirect_to_thanks
      end    
    end  
  end

  context "no current_user" do
    setup { @controller.stub!(:current_user, :return => nil) }
    context "with incomplete order" do
      setup do 
        Spree::Config.set({ :default_country_id => countries(:united_states).id })
        Spree::Config.set(:allow_anonymous_checkout => false) 
        @order = Factory(:order, :user => nil)
        @params = { :order_id => @order.number, :order_token => @order.token } 
      end
      context "GET /show" do
        setup { get :show } 
        should_redirect_to_register
      end
      context "GET /edit" do
        setup { get :edit } 
        should_redirect_to_register
      end
      context "with guest checkout enabled" do
        setup { Spree::Config.set({ :allow_guest_checkout => true }) }
        context "email assigned" do
          setup { @order.checkout.update_attribute("email", Faker::Internet.email) }
          context "GET /edit" do
            setup { get :edit } 
            should_respond_with :success
          end
        end
        context "no email assigned" do
          context "POST /register with valid email" do
            setup do
              @params[:checkout] = {:email => "test@foo.com"} 
              post :register
            end 
            should_redirect_to_first_step
            should "save the email property" do
              assert_equal "test@foo.com", assigns(:checkout).reload.email
            end
          end
          context "POST /register with invalid email" do
            setup do
              @params[:checkout] = {:email => "foo.com"} 
              post :register
            end 
            should_respond_with :success # validation error
            should "not save the email property" do
              assert_equal nil, assigns(:checkout).reload.email
            end
          end
          context "POST /register with blank email" do
            setup do
              @params[:checkout] = {:email => ""} 
              post :register
            end 
            should_respond_with :success # validation error
          end
        end
      end
      context "with anonymous checkout enabled" do
        setup { Spree::Config.set({ :allow_anonymous_checkout => true }) }
        context "GET /show" do
          setup { get :show } 
          should_redirect_to_first_step
        end
        context "GET /edit" do
          setup { get :edit } 
          should_render_template :edit
        end
      end
    end
  end
end
