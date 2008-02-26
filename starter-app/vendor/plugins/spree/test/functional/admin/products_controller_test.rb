require File.dirname(__FILE__) + '/../../test_helper'
require 'admin/products_controller'

# Re-raise errors caught by the controller.
class Admin::ProductsController; def rescue_action(e) raise e end; end

class Admin::ProductsControllerTest < Test::Unit::TestCase
  fixtures :products, :users, :roles, :roles_users

  def setup
    @controller = Admin::ProductsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    login_as :admin
    get :index
    assert_response :success
    assert assigns(:products)
  end

  def test_should_get_new
    login_as :admin
    get :new
    assert_response :success
  end
  
  def test_should_create_product
    login_as :admin
    old_count = Product.count
    post :create, :product => {:name => 'New Product', :description => 'New product description', :price => 5.00, :weight => 1}
    assert_equal old_count+1, Product.count
    
    assert_redirected_to product_path(assigns(:product))
  end

  def test_should_show_product
    login_as :admin
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    login_as :admin
    get :edit, :id => 1
    assert_response :success
  end
  
  def test_should_update_product
    login_as :admin
    put :update, :id => 1, :product => {:name => 'Update Product', :description => 'Updated product description', :price => 15.00, :weight => 1}
    assert_redirected_to product_path(assigns(:product))
  end
  
  def test_should_destroy_product
    login_as :admin
    old_count = Product.count
    delete :destroy, :id => 1
    assert_equal old_count-1, Product.count
    
    assert_redirected_to products_path
  end

  def test_index_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "index"
    )
  end
  
  def test_new_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "new"
    )
  end
  
  def test_create_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "create"
    )
  end
  
  def test_show_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "show"
    )
  end
  
  def test_edit_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "edit"
    )
  end

  def test_update_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "update"
    )
  end

  def test_destroy_access
    assert_users_access(
      {:admin => true, :quentin => false},   # admin can access, but quentin can't
      "destroy"
    )
  end
  
  def test_access_denied
    get "admin/products"
    assert_redirected_to login_path
  end
  
  def test_access_forbidden
    login_as :quentin
    get "admin/products"
    assert_template "layouts/admin"
    assert_select "div#main-content", "Access Forbidden"
  end
end
