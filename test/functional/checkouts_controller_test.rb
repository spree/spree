require 'test_helper'

class CheckoutsControllerTest < ActionController::TestCase
  fixtures :countries, :states, :gateways

  # context "given current_user" do
  #   setup do
  #     @user = Factory(:user, :email => "test@example.com")
  #     @controller.stub!(:current_user, :return => @user)
  #     @order = Factory.create(:order)
  #     @params = { :order_id => @order.number }
  #     session[:order_id] = @order.id.to_s
  #     @address = Factory.build(:address)
  #     @creditcard = Factory.build(:creditcard)
  #   end
  #   context "post" do
  #     setup do
  #       @params = { :final_answer => "yes", :order_id => @order.number }
  #       @shipping_method = Factory(:shipping_method)
  #       @params[:checkout] = {
  #         :bill_address_attributes => @address.attributes.symbolize_keys,
  #         :shipment_attributes => {
  #           :id => @order.shipment.id,
  #           :address_attributes => @address.attributes.symbolize_keys,
  #           :shipping_method_id => @shipping_method.id,
  #         },
  #         :creditcard => @creditcard.attributes.symbolize_keys,
  #       }
  #       post :update
  #     end
  #     should_change("Address.count", :by => 2) { Address.count }
  #     should_redirect_to("order completion page") { order_url(@order, :checkout_complete => true) }
  #     should "assign the current_user email" do
  #       assert_equal "test@example.com", assigns(:checkout).email
  #     end
  #     should "assign the requestor IP" do
  #       assert_equal "0.0.0.0", assigns(:checkout).ip_address
  #     end
  #     should "assign the requested shipping method" do
  #       assert_equal @shipping_method, assigns(:checkout).order.shipment.shipping_method
  #     end
  #     should "remove the order_id from the session" do
  #       assert_equal nil, session[:order_id]
  #     end
  #     should "not have any errors" do
  #       assert(assigns(:checkout).errors.empty?, "checkout has errors #{assigns(:checkout).errors.inspect}")
  #     end
  #   end
  #   context "xhr put" do
  #     setup { xhr :put, :update }
  #     should_respond_with :success
  #   end
  # 
  #   context "xhr put with valid coupon code" do
  #     setup do
  #       @coupon = Factory(:coupon, :code => "FOO")
  #       xhr :put, :update, :checkout => { :coupon_code => "FOO" }, :order_id => @order.id.to_s
  #     end
  #     should_change("@order.credits.count", :by => 1) { @order.credits.count }
  #   end
  # 
  #   context "xhr put with invalid coupon code" do
  #     setup { xhr :put, :update, :coupon_code => "BOGUS", :order_id => @order.id.to_s }
  #     should_respond_with :success
  #     should_not_change("@order.credits.count") { @order.credits.count }
  #   end
  # 
  #   context "xhr put with bill and ship address" do
  #     setup do
  #       xhr :put, :update, :bill_address_attributes => Factory.build(:address).attributes.symbolize_keys,
  #         :ship_address_attributes => Factory.build(:address).attributes.symbolize_keys
  #     end
  #     should_respond_with :success
  #   end
  # end      
                
  context "current_user" do
    setup { set_current_user }
    context "with incomplete order" do
      setup do 
        Spree::Config.set({ :default_country_id => countries(:united_states).id })
        @order = Factory(:order)
        @params = { :order_id => @order.number } 
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
    end
    context "complete order" do
      setup do 
        @order = create_complete_order
        @params = { :order_id => @order.number } 
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
        @order = Factory(:order)
        @params = { :order_id => @order.number } 
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
