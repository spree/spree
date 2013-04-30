require 'spec_helper'

module Spree
  describe Api::UsersController do
    render_views

    let(:user) { create(:user) }
    let(:stranger) { create(:user, :email => 'stranger@example.com') }
    let(:attributes) { [:id, :email, :created_at, :updated_at] }

    before { stub_authentication! }

    context "as a normal user" do
      before { Spree::LegacyUser.stub :find_by_spree_api_key => user }

      it "can get own details" do
        api_get :show, :id => user.id

        json_response['email'].should eq user.email
      end

      it "cannot get other users details" do
        api_get :show, :id => stranger.id

        assert_not_found!
      end

      it "can learn how to create a new user" do
        api_get :new
        json_response["attributes"].should == attributes.map(&:to_s)
      end

      it "can create a new user" do
        api_post :create, :user => { :email => 'new@example.com', :password => 'spree123', :password_confirmation => 'spree123' }
        json_response['email'].should eq 'new@example.com'
      end

      # there's no validations on LegacyUser?
      xit "cannot create a new user with invalid attributes" do
        api_post :create, :user => {}
        response.status.should == 422
        json_response["error"].should == "Invalid resource. Please fix errors and try again."
        errors = json_response["errors"]
      end

      it "can update own details" do
        api_put :update, :id => user.id, :user => { :email => "mine@example.com" }
        json_response['email'].should eq 'mine@example.com'
      end

      it "cannot update other users details" do
        api_put :update, :id => stranger.id, :user => { :email => "mine@example.com" }
        assert_not_found!
      end

      it "can delete itself" do
        api_delete :destroy, :id => user.id
        response.status.should == 204
      end

      it "cannot delete other user" do
        api_delete :destroy, :id => stranger.id
        assert_not_found!
      end

      it "should only get own details on index" do
        2.times { create(:user) }
        api_get :index

        Spree.user_class.count.should eq 3
        json_response['count'].should eq 1
        json_response['users'].size.should eq 1
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "gets all users" do
        Spree::LegacyUser.stub :find_by_spree_api_key => current_api_user

        2.times { create(:user) }

        api_get :index
        Spree.user_class.count.should eq 2
        json_response['count'].should eq 2
        json_response['users'].size.should eq 2
      end

      it 'can control the page size through a parameter' do
        2.times { create(:user) }
        api_get :index, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end

      it 'can query the results through a paramter' do
        expected_result = create(:user, :email => 'brian@spreecommerce.com')
        api_get :index, :q => { :email_cont => 'brian' }
        json_response['count'].should == 1
        json_response['users'].first['email'].should eq expected_result.email
      end

      it "can create" do
        api_post :create, :user => { :email => "new@example.com", :password => 'spree123', :password_confirmation => 'spree123' }
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      it "can destroy user without orders" do
        user.orders.destroy_all
        api_delete :destroy, :id => user.id
        response.status.should == 204
      end

      it "cannot destroy user with orders" do
        create(:completed_order_with_totals, :user => user)
        api_delete :destroy, :id => user.id
        json_response["exception"].should eq "Spree::LegacyUser::DestroyWithOrdersError"
        response.status.should == 422
      end

    end
  end
end
