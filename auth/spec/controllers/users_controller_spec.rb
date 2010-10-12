require 'spec_helper'

describe UsersController do
  
  let(:user) { mock_model(User, :email => "spree@example.com") }
  
  context "#create" do

    before do
      post :create, {:user => {:email => "foobar@example.com", :password => "foobar123", :password_confirmation => "foobar123"} }
    end

    it "should create a new user" do
      assigns[:user].new_record?.should be_false
    end

    it "should automatically authenticate the new user" do
      session[:user_credentials_id].should_not be_nil
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
end