require File.dirname(__FILE__) + '/../../test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
  setup do
    UserSession.create(Factory(:admin_user))
  end

  context "on put to :generate_api_key" do
    setup do
      @user = Factory(:admin_user)
      put :generate_api_key, :id => @user.id
      @user.reload
    end
    should_respond_with :redirect
    should "generate the key" do
      assert_equal 40, @user.api_key.to_s.length
    end
  end

  context "on put to :clear_api_key" do
    setup do
      @user = Factory(:admin_user, :api_key => 'abc')
      put :clear_api_key, :id => @user.id
      @user.reload
    end
    should_respond_with :redirect
    should "clear the key" do
      assert @user.api_key.blank?
    end
  end

end