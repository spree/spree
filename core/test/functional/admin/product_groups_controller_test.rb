require 'test_helper'

class Admin::ProductGroupsControllerTest < ActionController::TestCase
  context "ProductGroupsController" do
    setup do
      UserSession.create(Factory(:admin_user))
      @pg = Factory(:product_group)
    end

    context "on GET to :index" do
      setup do
        get :index
      end

      should_respond_with :success
    end

    context "on GET to :show" do
      setup do
        get :show, {:id => @pg.id}
      end

      should_respond_with :success
    end

    # TODO: test the addition of non-ordering scopes
    context "on POST to :create" do
      setup do
        post :create, {
            "product_group"=>{ "name"=>"TestableProductGroup", 
                               "order_scope"=>"descend_by_popularity" 
            }
        }
      end

      should_respond_with :redirect
      should_change("ProductGroup.count", :by => 1) { ProductGroup.count }
      should_change("ProductScope.count", :by => 1) { ProductScope.count }
    end
  end
end
