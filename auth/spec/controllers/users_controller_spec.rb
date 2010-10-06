require 'spec_helper'

describe UsersController do
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
end