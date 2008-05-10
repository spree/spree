require File.dirname(__FILE__)+'/../../test_helper'

class Helpers::InternalTest < Test::Unit::TestCase
  def setup
    @controller = PostsController.new

    @params = stub :[] => "1"
    @controller.stubs(:params).returns(@params)

    @object = Post.new
    Post.stubs(:find).with("1").returns(@object)
    
    @collection = mock()
    Post.stubs(:find).with(:all).returns(@collection)
  end
  
  context "response_for" do
    setup do
      @options = ResourceController::ActionOptions.new
      @options.response {|wants| wants.html}
      @controller.expects(:respond_to).yields(mock(:html => ""))
      @controller.stubs(:options_for).with(:create).returns( @options )
    end

    should "yield a wants object to the response block" do      
      @controller.send :response_for, :create
    end
  end
  
  context "after" do
    setup do
      @options = ResourceController::FailableActionOptions.new
      @options.success.after { }
      @controller.stubs(:options_for).with(:create).returns( @options )
      @nil_options = ResourceController::FailableActionOptions.new      
      @controller.stubs(:options_for).with(:non_existent).returns(@nil_options)
    end

    should "grab the correct block for after create" do
      @controller.send :after, :create
    end

    should "not choke if there is no block" do
      assert_nothing_raised do
        @controller.send :after, :non_existent
      end
    end
  end
  
  context "before" do
    setup do
      PostsController.stubs(:non_existent).returns ResourceController::ActionOptions.new
    end
    
    should "not choke if there is no block" do
      assert_nothing_raised do
        @controller.send :before, :non_existent
      end
    end
  end
  
  context "get options for action" do
    setup do
      @create = ResourceController::FailableActionOptions.new
      PostsController.stubs(:create).returns @create
    end

    should "get correct object for failure action" do
      assert_equal @create.fails, @controller.send(:options_for, :create_fails)
    end
    
    should "get correct object for successful action" do
      assert_equal @create.success, @controller.send(:options_for, :create)
    end
    
    should "get correct object for non-failable action" do
      @index = ResourceController::ActionOptions.new
      PostsController.stubs(:index).returns @index
      assert_equal @index, @controller.send(:options_for, :index)
    end
    
    should "understand new_action to mean new" do
      @new_action = ResourceController::ActionOptions.new
      PostsController.stubs(:new_action).returns @new_action
      assert_equal @new_action, @controller.send(:options_for, :new_action)
    end
  end
end
