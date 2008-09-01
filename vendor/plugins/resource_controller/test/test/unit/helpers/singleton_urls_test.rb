require File.dirname(__FILE__)+'/../../test_helper'

class Helpers::SingletonUrlsTest < Test::Unit::TestCase
  
  context "*_url_options helpers" do
    setup do
      @account_controller = AccountsController.new
      @params = stub :[] => ""
      @account_controller.stubs(:params).returns(@params)
      @request = stub :path => ""
      @account_controller.stubs(:request).returns(@request)    
    end   
    
    should "return the correct object options" do
      assert_equal [nil, nil, :account], @account_controller.send(:object_url_options)
    end
       
    context "with parent" do
      setup do
        @user = mock
        @image = stub()        
        @image_controller = ImagesController.new
        @image_params = stub()
        @image_params.stubs(:[]).with(:user_id).returns 2
        @image_controller.stubs(:params).returns(@image_params)
        @image_controller.expects(:parent_object).returns @user        
        @image_request = stub :path => ""
        @image_controller.stubs(:request).returns(@image_request)
      end
      
      should "return the correct object options" do
        assert_equal [:edit, [:user, @user], :image], @image_controller.send(:object_url_options, :edit)
      end      
    end
    
    context "with singleton parent" do
      setup do
        @options_controller = OptionsController.new
        @options_params = stub()
        @options_params.stubs(:[]).with('option').returns ""
        @options_params.stubs(:[]).with(:id).returns 1      
        @options_params.stubs(:[]).with(:account_id).returns nil         
        @options_controller.stubs(:params).returns(@options_params)

        @option = Option.new

        @account = Account.new      
        @options_controller.stubs(:parent_object).returns(@account)

        @request = stub :path => "account/options/1"
        @options_controller.stubs(:request).returns(@request) 

        @options = stub()
        Account.any_instance.stubs(:options).returns(@options)
      end
      
      should "return the correct object options" do
        @options.expects(:find).with(1).returns(@option)
        assert_equal [:edit, :account, [:option, @option]], @options_controller.send(:object_url_options, :edit)
      end
      
      should "return the correct object options for collection" do
        assert_equal [:account, :options], @options_controller.send(:collection_url_options)
      end
    end
  end
end