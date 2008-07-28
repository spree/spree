require File.dirname(__FILE__) + '/../test_helper'
require 'comments_controller'

# Re-raise errors caught by the controller.
class CommentsController; def rescue_action(e) raise e end; end

class CommentsControllerTest < Test::Unit::TestCase
  def setup
    @controller = CommentsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @comment    = Comment.find 1
  end
  
  context "with parent post" do
    should_be_restful do |resource|
      resource.formats = [:html]
    
      resource.parent = :post
    end
  end
  
  should_be_restful do |resource|
    resource.formats = [:html]
  end
end
