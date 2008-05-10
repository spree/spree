require File.dirname(__FILE__) + '/../test_helper'
require 'tags_controller'

# Re-raise errors caught by the controller.
class TagsController; def rescue_action(e) raise e end; end

class TagsControllerTest < Test::Unit::TestCase
  def setup
    @controller = TagsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @tag        = Tag.find 1
  end
  
  context "with photo as parent" do
    context "get to :index" do
      setup do
        get :index, :photo_id => 1
      end

      should_assign_to :products
      should_render_template "index"
      should_respond_with :success
      
      should "respond with html" do
        assert_equal 'text/html', @response.content_type
      end
    end
    
    context "xhr to :index" do
      setup do
        xhr :get, :index, :photo_id => 1
      end

      should_assign_to :products
      should_respond_with :success

      should "respond with rjs" do
        assert_equal 'text/javascript', @response.content_type
      end
    end
    
    context "post to create" do
      setup do
        post :create, :photo_id => 1, :tag => {:name => "Hello!"}
      end

      should "add tag to photo" do
        assert assigns(:photo).tags.include?(assigns(:tag)), "photo does not include new tag"
      end
    end
  end
  
  context "without photo as parent" do
    should_be_restful do |resource|
      resource.formats = [:html]
    end
    
    should "render text for a missing object" do
      get :show, :id => 50000
      assert @response.body.match(/not found/i), @response.body
    end
  end
end
