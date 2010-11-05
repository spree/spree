require 'spec_helper'

describe UsersController do

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
    let(:user) { mock_model(User, :email => "spree@example.com") }

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
end