require 'spec_helper'

describe UsersController do

  let(:user) { Factory(:user) }
  before do
    user.roles.destroy_all #ensure not admin
    controller.stub :current_user => nil
  end

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

  context "#update" do
    context "when updating own account" do
      before { controller.stub :current_user => user }

      it "should perform update" do
        put :update, {:user => {:email => "mynew@email-address.com" } }
        assigns[:user].email.should == "mynew@email-address.com"
        response.should redirect_to(account_url)
      end
    end

    context "when attempting to update other account" do
      it "should not allow update" do
        put :update, {:user => {:email => "mynew@email-address.com" } }
        response.should redirect_to(login_url)
        flash[:error].should == I18n.t(:authorization_failure)
      end
    end
  end

end
