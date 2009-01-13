require File.dirname(__FILE__) + '/../test_helper'
require 'states_controller'

# Re-raise errors caught by the controller.
class StatesController; def rescue_action(e) raise e end; end

class StatesControllerTest < Test::Unit::TestCase
  fixtures :states

  def setup
    @controller = StatesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:states)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_state
    assert_difference('State.count') do
      post :create, :state => { }
    end

    assert_redirected_to state_path(assigns(:state))
  end

  def test_should_show_state
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end

  def test_should_update_state
    put :update, :id => 1, :state => { }
    assert_redirected_to state_path(assigns(:state))
  end

  def test_should_destroy_state
    assert_difference('State.count', -1) do
      delete :destroy, :id => 1
    end

    assert_redirected_to states_path
  end
end
