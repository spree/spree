require File.dirname(__FILE__) + '/../test_helper'
require 'addresses_controller'

# Re-raise errors caught by the controller.
class AddressesController; def rescue_action(e) raise e end; end

class AddressesControllerTest < Test::Unit::TestCase
  fixtures :addresses

  def setup
    @controller = AddressesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:addresses)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_address
    assert_difference('Address.count') do
      post :create, :address => { :country_id => 1, :user_id => 1, :state_id => 1}
    end

    assert_redirected_to address_path(assigns(:address))
  end

  def test_should_show_address
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end

  def test_should_update_address
    put :update, :id => 1, :address => { }
    assert_redirected_to address_path(assigns(:address))
  end

  def test_should_destroy_address
    assert_difference('Address.count', -1) do
      delete :destroy, :id => 1
    end

    assert_redirected_to addresses_path
  end
end
