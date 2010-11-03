require 'spec_helper'

describe OrdersController do

  let(:user) { mock_model User, :persistence_token => "foo", :has_role? => false, :email => "user@example.com" }
  let(:guest_user) { mock_model User, :persistence_token => "guest_token", :has_role? => false, :email => "user@example.com" }

  it "should understand order routes with token" do
    assert_routing("/orders/R123456/token/ABCDEF", {:controller => "orders", :action => "show", :id => "R123456", :token => "ABCDEF"})
    token_order_path("R123456", "ABCDEF").should == "/orders/R123456/token/ABCDEF"
  end

  context "when no order exists in the session" do
    let(:order) { Order.new }

    before { Order.stub :new => order }

    context "#populate" do

      context "when authenticated as a guest" do
        before { controller.stub :auth_user => guest_user }

        it "should not create an anonymous user" do
          User.should_not_receive :anonymous!
          post :populate
        end

        it "should associate the new order with the registered user" do
          post :populate
          order.user.should == guest_user
        end
      end

      context "when authenticated as a registered user" do
        before { controller.stub :current_user => user }

        it "should not create an anonymous user" do
          User.should_not_receive :anonymous!
          post :populate
          session[:guest_token].should be_nil
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
          session[:guest_token].should == "guest_token"
        end

        it "should associate the new order with the anonymous user" do
          User.stub :anonymous! => guest_user
          #User.stub(:find_by_persistence_token).with('guest_token').and_return guest_user
          #controller.stub :check_authorization => true
          post :populate
          order.user.should == guest_user
        end
      end

    end
  end

  context "when an order exists in the session" do
    let(:order) { mock_model(Order, :user => user).as_null_object }

    before do
      controller.stub :current_order => order
      controller.stub :current_user => user
    end

    context "#populate" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :populate
      end
    end

    context "#edit" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        get :edit
      end
    end

    context "#update" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :update
      end
    end

    context "#empty" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :empty
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
          session[:guest_token].should == "ABC"
        end
      end

      context "when no token present" do
        it "should not store a guest_token in the session" do
          get :show, {:id => "R123"}
          session[:guest_token].should be_nil
        end

        it "should redirect to login_path" do
          get :show, {:id => "R123"}
          response.should redirect_to login_path
        end
      end
    end
  end

end
