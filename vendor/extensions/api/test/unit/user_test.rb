require 'test_helper'

class UserTest < Test::Unit::TestCase
  
  context "api access" do
    setup do
      @user = Factory(:admin_user)
    end
    
    context "generate and clear api key" do
      should "set api_key to a 40 character SHA" do
        @user.generate_api_key!
        assert_equal 40, @user.api_key.to_s.length, "should have been a 40 character string"
        @user.clear_api_key!
        assert @user.api_key.blank?, "api key should have been cleared"
      end
    end

  end
  
end