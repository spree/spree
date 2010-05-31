require 'test_helper'

class ProductsControllerTest < ActionController::TestCase
  context "on get to :index" do
    setup do
      get :index
    end
    should_respond_with :success
    should_not_set_the_flash    
  end
  
  context "with a Taxonomy without a root Taxon" do
    setup do
      taxonomy = Factory(:taxonomy)
      taxonomy2 = Factory(:taxonomy)
      taxonomy2.root.destroy
      get :index
    end
    should_respond_with :success
    should "render only one Taxonomy" do
      assert_select "#taxonomies .navigation-list li"
    end
  end
end
