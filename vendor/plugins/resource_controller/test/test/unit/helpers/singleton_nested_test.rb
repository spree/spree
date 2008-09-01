require File.dirname(__FILE__)+'/../../test_helper'

class UsersControllerMock
  include ResourceController::Helpers
  extend ResourceController::Accessors
  class_reader_writer :belongs_to
end

class ImagesControllerMock
  include ResourceController::Helpers
  extend ResourceController::Accessors
  include ResourceController::Helpers::SingletonCustomizations   
  class_reader_writer :belongs_to
  belongs_to :user 
end

class Helpers::SingletonNestedTest < Test::Unit::TestCase
  def setup
    @controller = UsersControllerMock.new
    @params = stub :[] => "1"
    @controller.stubs(:params).returns(@params)
    @request = stub :path => ""
    @controller.stubs(:request).returns(@request)        
  end
  
  context "singleton parent_type helper" do
    setup do
      @image_controller = ImagesControllerMock.new
      @image_params = stub()
      @image_params.stubs(:[]).with(:user_id).returns 2
      @image_controller.stubs(:params).returns(@image_params)
    end

    should "get the params for the current parent" do
      assert_equal :user, @image_controller.send(:parent_type)
    end
    
    context "with multiple possible parents" do
      setup do
        ImagesControllerMock.class_eval do
          belongs_to :user, :group
        end
        @image_params = stub()
        @image_params.stubs(:[]).with(:group_id).returns 5
        @image_params.stubs(:[]).with(:user_id).returns nil
        @image_controller.stubs(:params).returns(@image_params)
      end

      should "get the params for whatever models are available" do
        assert_equal :group, @image_controller.send(:parent_type)
      end
    end
    
    context "with no possible parent" do
      should "return nil" do
        assert_nil @controller.send(:parent_type)
      end
    end
  end
  
  context "singleton parent_object helper" do
    setup do
      @image_controller = ImagesControllerMock.new
      @request = stub :path => ""
      @image_controller.stubs(:request).returns(@request)          
      @image_params = stub()
      @image_params.stubs(:[]).with(:user_id).returns 2      
      @image_controller.stubs(:params).returns(@image_params)
      @user = User.new
      User.stubs(:find).with(2).returns @user
    end

    should "return image with id 2" do
      assert_equal @user, @image_controller.send(:parent_object)
    end
  end 
end