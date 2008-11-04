require File.dirname(__FILE__) + '/../../test_helper'
require 'cms/photos_controller'

# Re-raise errors caught by the controller.
class Cms::PhotosController; def rescue_action(e) raise e end; end

class Cms::PhotosControllerTest < Test::Unit::TestCase
  def setup
    @controller = Cms::PhotosController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @photo      = Photo.find 1
  end
  
  context "with personnel as parent" do
    context "on get to :index" do
      setup do
        get :index, :personnel_id => 1
      end

      should_respond_with :success
      should_render_template "index"
      should_assign_to :photos
      should_assign_to :personnel
      should "scope photos to personnel" do
        assert assigns(:photos).all? { |photo| photo.personnel.id == 1 }
      end
    end
    
    context "on post to :create" do
      setup do
        post :create, :personnel_id => 1, :photo => {}
      end

      should_redirect_to 'cms_personnel_photo_path(@photo.personnel, @photo)'
      should_assign_to :photo
      should_assign_to :personnel
      should "scope photo to personel" do
        assert personnel(:one), assigns(:photo).personnel
      end
    end
  end
end
