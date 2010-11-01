require 'spec_helper'

describe UsersController do

  let(:user) { mock_model(User, :email => "spree@example.com", :has_role? => false) }
  before { controller.stub :current_user => nil }

  context "#create" do

    it "should create a new user" do
      post :create, {:user => {:email => "foobar@example.com", :password => "foobar123", :password_confirmation => "foobar123"} }
      assigns[:user].new_record?.should be_false
    end

    # This is built into Devise see sign_in_and_redirect() helper
    #it "should automatically authenticate the new user" do
    #  post :create, {:user => {:email => "foobar@example.com", :password => "foobar123", :password_confirmation => "foobar123"} }
    #  session[:user_credentials_id].should_not be_nil
    #end

    context "when an order exists in the session" do
      let(:order) { mock_model Order }
      before { controller.stub :current_order => order }

      it "should assign the user to the order" do
        order.should_receive(:associate_user!)
        post :create, {:user => {:email => "foobar@spreecommerce.com", :password => "foobar123", :password_confirmation => "foobar123"} }
      end
    end
  end

end