require File.dirname(__FILE__)+'/../../test_helper'

class Helpers::SingletonCurrentObjectsTest < Test::Unit::TestCase
  context "singleton" do
    setup do
      @image_controller = ImagesController.new
      @image_params = stub()
      @image_params.stubs(:[]).with(:user_id).returns 2
      @image_params.stubs(:[]).with('image').returns ""
      @image_controller.stubs(:params).returns(@image_params)

      @request = stub :path => ""
      @image_controller.stubs(:request).returns(@request)
      @user = stub()
      User.expects(:find).with(2).returns(@user)
      @image = stub()
    end  

    context "build object helper with parent" do
      should "build new object" do
        @user.expects(:build_image).with("").returns("a new image")      
        assert_equal "a new image", @image_controller.send(:build_object)
      end
    end

    context "object helper with parent" do
      should "fetch the correct object" do
        @user.expects(:image).returns(@image)
        assert_equal @image, @image_controller.send(:object)
      end
    end  
  end
  
  context "with singleton parent" do
    setup do
      @options_controller = OptionsController.new
      @options_params = stub :[] => "1"
      @options_params.stubs(:[]).with('option').returns ""
      @options_params.stubs(:[]).with(:id).returns 1      
      @options_controller.stubs(:params).returns(@options_params)

      @option = Option.new
      
      @account = Account.new      
      @options_controller.stubs(:parent_object).returns(@account)

      @request = stub :path => "account/options/1"
      @options_controller.stubs(:request).returns(@request) 
      
      @options = stub()
      Account.any_instance.stubs(:options).returns(@options)      
    end
    
    context "build object helper" do
      should "build new object" do
        @options.expects(:build).with("").returns("a new option")      
        assert_equal "a new option", @options_controller.send(:build_object)
      end
    end

    context "object helper" do
      should "fetch the correct object" do
        @options.expects(:find).with(1).returns(@option)        
        assert_equal @option, @options_controller.send(:object)
      end
    end        
  end
end
