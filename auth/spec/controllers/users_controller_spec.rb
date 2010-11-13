require 'spec_helper'

describe UsersController do

  let(:user) { mock_model(User, :email => "spree@example.com", :has_role? => false) }

  context "#create" do

    it "should create a new user" do
      post :create, {:user => {:email => "foobar@example.com", :password => "foobar123", :password_confirmation => "foobar123"} }
      assigns[:user].new_record?.should be_false
    end

    it "should automatically authenticate the new user" do
      post :create, {:user => {:email => "foobar@example.com", :password => "foobar123", :password_confirmation => "foobar123"} }
      session[:user_credentials_id].should_not be_nil
    end

    context "when an order exists in the session" do
      let(:order) { mock_model Order }
      before { controller.stub :current_order => order }

      it "should assign the user to the order" do
        order.should_receive(:associate_user!)
        post :create, {:user => {:email => "foobar@spreecommerce.com", :password => "foobar123", :password_confirmation => "foobar123"} }
      end
    end
  end

  context "#update" do

    before do
      controller.stub :current_user => user
      user.stub :update_attributes => true
      user.stub(:has_role?).with('admin').and_return(true)
    end

    it "should create a user session after update" do
      UserSession.should_receive :create
      put :update, {:user => {:password => "newpw", :password_confirmation => "newpw", :email => user.email}}
    end
  end

  context "#show" do
    context "when authenticated" do

      before { controller.stub :current_user => user }

      it "should not redirect to login_path when logged in" do
        user.stub_chain :orders, :complete => []
        get :show, {:id => "blah"}
        response.should_not redirect_to login_path
      end
    end

    context "when not authenticated" do

       before { controller.stub :current_user => nil }

       it "should redirect to login_path when not logged in" do
         get :show, {:id => "blah"}
         response.should redirect_to login_path
       end

     end
  end

  context "#edit" do
    context "when authenticated" do

      before do
        controller.stub :current_user => user
        user.stub(:has_role?).with('admin').and_return(false)
      end

      it "should not redirect to login_path when logged in" do
         get :edit, {:id => "blah"}
         response.should_not redirect_to login_path
       end
    end

    context "when not authenticated" do

       before { controller.stub :current_user => nil }

       it "should redirect to login_path when not logged in" do
         get :edit, {:id => "blah"}
         response.should redirect_to login_path
       end

     end
  end
end