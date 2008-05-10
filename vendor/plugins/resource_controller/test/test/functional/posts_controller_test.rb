require File.dirname(__FILE__) + '/../test_helper'
require 'posts_controller'

# Re-raise errors caught by the controller.
class PostsController; def rescue_action(e) raise e end; end

class PostsControllerTest < Test::Unit::TestCase
  def setup
    @controller = PostsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @post       = Post.find 1
  end
  
  should_be_restful do |resource|
    resource.formats = [:html]

    resource.actions = :all
  end
  
  context "on post to :create" do
    setup do
      post :create, :post => {}
    end

    should "name the post 'a great post'" do
      assert_equal 'a great post', assigns(:post).title
    end
    
    should "give the post a body of '...'" do
      assert_equal '...', assigns(:post).body
    end
  end
end
