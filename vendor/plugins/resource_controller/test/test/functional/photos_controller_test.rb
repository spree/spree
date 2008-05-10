require File.dirname(__FILE__) + '/../test_helper'
require 'photos_controller'

# Re-raise errors caught by the controller.
class PhotosController; def rescue_action(e) raise e end; end

class PhotosControllerTest < Test::Unit::TestCase
  def setup
    @controller = PhotosController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @photo      = Photo.find 1
  end

  context "actions specified" do
    should "not respond to update" do
      assert !@controller.respond_to?(:update)
    end
  end
  
  should_be_restful do |resource|
    resource.formats = [:html]
    
    resource.actions = [:index, :new, :create, :destroy, :show, :edit]
  end
  
  context "with user as parent" do
    context "on get to :index" do
      setup do
        get :index, :user_id => 1
      end

      should_respond_with :success
      should_render_template "index"
      should_assign_to :photos
      should_assign_to :user
      should "scope photos to user" do
        assert assigns(:photos).all? { |photo| photo.user.id == 1 }
      end
    end
    
    context "on post to :create" do
      setup do
        post :create, :user_id => 1, :photo => {}
      end

      should_redirect_to 'user_photo_path(@photo.user, @photo)'
      should_assign_to :photo
      should_assign_to :user
      should "scope photo to user" do
        assert accounts(:one), assigns(:photo).user
      end
    end
  end
  
  # url helpers integration
  
  context "url, path, and hash_for helpers" do
    setup do
      get :index
    end

    should "return collection url" do
      assert_equal photos_url, @controller.send(:collection_url)
    end
    
    should "return collection path" do
      assert_equal photos_path, @controller.send(:collection_path)
    end
    
    should "return hash for collection url" do
      assert_equal hash_for_photos_url, @controller.send(:hash_for_collection_url)
    end
    
    should "return hash for collection path" do
      assert_equal hash_for_photos_path, @controller.send(:hash_for_collection_path)
    end
    
    should "return object url" do
      assert_equal photo_url(photos(:one)), @controller.send(:object_url, photos(:one))
    end
    
    should "return object path" do
      assert_equal photo_path(photos(:one)), @controller.send(:object_path, photos(:one))
    end
    
    should "return hash_for object url" do
      assert_equal hash_for_photo_url(:id => @photo.to_param), @controller.send(:hash_for_object_url, photos(:one))
    end
    
    should "return hash_for object path" do
      assert_equal hash_for_photo_path(:id => @photo.to_param), @controller.send(:hash_for_object_path, photos(:one))
    end
    
    should "return edit object url" do
      assert_equal edit_photo_url(photos(:one)), @controller.send(:edit_object_url, photos(:one))
    end
    
    should "return edit object path" do
      assert_equal edit_photo_path(photos(:one)), @controller.send(:edit_object_path, photos(:one))
    end
    
    should "return hash_for_edit object url" do
      assert_equal hash_for_edit_photo_url(:id => @photo.to_param), @controller.send(:hash_for_edit_object_url, photos(:one))
    end
    
    should "return hash_for_edit object path" do
      assert_equal hash_for_edit_photo_path(:id => @photo.to_param), @controller.send(:hash_for_edit_object_path, photos(:one))
    end
    
    should "return new object url" do
      assert_equal new_photo_url, @controller.send(:new_object_url)
    end
    
    should "return new object path" do
      assert_equal new_photo_path, @controller.send(:new_object_path)
    end
    
    should "return hash_for_new object url" do
      assert_equal hash_for_new_photo_url, @controller.send(:hash_for_new_object_url)
    end
    
    should "return hash_for_new object path" do
      assert_equal hash_for_new_photo_path, @controller.send(:hash_for_new_object_path)
    end
  end
  
end
