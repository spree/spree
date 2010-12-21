require 'spec_helper'

describe OrdersController do
  ORDER_TOKEN = "ORDER_TOKEN"

  let(:user) { mock_model User, :has_role? => false, :email => "user@example.com", :anonymous? => false }
  let(:guest_user) { mock_model User, :has_role? => false, :email => "user@example.com", :anonymous? => false }
  let(:order) { Order.new }

  it "should understand order routes with token" do
    assert_routing("/orders/R123456/token/ABCDEF", {:controller => "orders", :action => "show", :id => "R123456", :token => "ABCDEF"})
    token_order_path("R123456", "ABCDEF").should == "/orders/R123456/token/ABCDEF"
  end

  before do
    controller.stub :current_user => nil
    User.stub :anonymous! => guest_user
  end

  context "when no order exists in the session" do
    before { Order.stub :new => order }

    context "#populate" do

      context "when not logged in" do
        it "should create an anonymous user" do
          User.should_receive :anonymous!
          post :populate
        end
      end

      context "when authenticated as a registered user" do
        before { controller.stub :current_user => user }

        it "should not create an anonymous user" do
          User.should_not_receive :anonymous!
          post :populate
          session[:access_token].should be_nil
        end

        it "should associate the new order with the registered user" do
          post :populate
          order.user.should == user
        end
      end

      context "when not authenticated" do
        it "should create an anonymous user" do
          User.should_receive(:anonymous!).and_return guest_user
          post :populate
        end

        it "should associate the new order with the anonymous user" do
          post :populate
          order.user.should == guest_user
        end

        context "when there is an order token" do
          before { order.stub :token => ORDER_TOKEN }

          it "should store the token in the session" do
            post :populate
            session[:access_token].should == ORDER_TOKEN
          end

          it "should repalce any previous access tokens" do
            session[:access_token] = "OLD_TOKEN"
            post :populate
            session[:access_token].should == ORDER_TOKEN
          end

        end

      end

    end
  end

  context "when an order exists in the session" do
    let(:token) { "some_token" }

    before do
      controller.stub :current_order => order
      controller.stub :current_user => user
    end

    context "#populate" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :populate, :token => token
      end
    end

    context "#edit" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        get :edit, :token => token
      end
    end

    context "#update" do
      it "should check if user is authorized for :edit" do
        order.stub :update_attributes
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :update, :token => token
      end
    end

    context "#empty" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order, token)
        post :empty, :token => token
      end
    end

  end

  context "when no authenticated user" do
    let(:order) { mock_model(Order, :user => user).as_null_object }

    context "#show" do
      before { Order.stub :find_by_number => order }

      context "when token parameter present" do
        it "should store as guest_token in session" do
          get :show, {:id => "R123", :token => "ABC"}
          session[:access_token].should == "ABC"
        end
      end

      context "when no token present" do
        it "should not store a guest_token in the session" do
          get :show, {:id => "R123"}
          session[:access_token].should be_nil
        end

        it "should redirect to login_path" do
          get :show, {:id => "R123"}
          response.should redirect_to login_path
        end
      end
    end
  end

end
