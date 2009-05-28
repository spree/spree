require 'test_helper'

class ProductsControllerTest < ActionController::TestCase
  context "on get to :index" do
    setup do
      get :index
    end
    should_respond_with :success
    should_assign_to :product_cols
    should_not_set_the_flash    
  end
end
