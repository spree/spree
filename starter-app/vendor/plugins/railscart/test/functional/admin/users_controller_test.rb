require File.dirname(__FILE__) + '/../../test_helper'
require 'admin/users_controller'

# Re-raise errors caught by the controller.
class Admin::UsersController; def rescue_action(e) raise e end; end

class Admin::UsersControllerTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @controller = Admin::UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as :admin
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:users)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_should_create_user
    old_count = User.count
    post :create, :user => {:login => 'testuser', :email => 'test@example.com', :password => 'pa55w0rd', :password_confirmation => 'pa55w0rd' }
    assert_equal old_count+1, User.count
  
    assert_redirected_to users_path
  end

  def test_should_show_user
    get :show, :id => 1
    assert_response :success
  end

#  def test_should_get_edit
#    get :edit, :id => 1
#    assert_response :success
#  end
  
#  def test_should_update_user
#    put :update, :id => 1, :user => { }
#    assert_redirected_to user_path(assigns(:user))
#  end
  
#  def test_should_destroy_user
#    old_count = User.count
#    delete :destroy, :id => 1
#    assert_equal old_count-1, User.count
    
#    assert_redirected_to admin_users_path
#  end
end
