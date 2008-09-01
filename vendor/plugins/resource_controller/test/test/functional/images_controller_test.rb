require File.dirname(__FILE__) + '/../test_helper'
require 'images_controller'

# Re-raise errors caught by the controller.
class ImagesController; def rescue_action(e) raise e end; end

class ImagesControllerTest < Test::Unit::TestCase
  def setup
    @controller           = ImagesController.new
    @request              = ActionController::TestRequest.new
    @response             = ActionController::TestResponse.new
    @image = images :one
  end

  context "with user as parent" do
    
    context "on post to :create" do
      setup do
        post :create, :user_id => 1, :photo => {}
      end

      should_redirect_to 'user_image_path(@image.user)'
      should_assign_to :image
      should_assign_to :user
      should "scope image to user" do
        assert users(:one), assigns(:image).user
      end
    end
    
  end  
  
  should "not respond to show" do
    assert_raise(ActionController::UnknownAction) do
      get :show
    end
  end
end
