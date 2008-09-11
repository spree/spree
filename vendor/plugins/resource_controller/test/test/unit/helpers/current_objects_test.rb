require File.dirname(__FILE__)+'/../../test_helper'

class Helpers::CurrentObjectsTest < Test::Unit::TestCase
  def setup
    @controller = PostsController.new

    @params = stub :[] => "1"
    @controller.stubs(:params).returns(@params)
    
    @request = stub :path => ""
    @controller.stubs(:request).returns(@request)    

    @object = Post.new
    Post.stubs(:find).with("1").returns(@object)
    
    @collection = mock()
    Post.stubs(:find).with(:all).returns(@collection)
  end
  
  context "model helper" do
    should "return constant" do
      assert_equal Post, @controller.send(:model)
    end
  end
  
  context "collection helper" do
    should "find all" do
      assert_equal @collection, @controller.send(:collection)
    end
  end
  
  context "param helper" do
    should "return the correct param" do
      assert_equal "1", @controller.send(:param)
    end
  end
  
  context "object helper" do    
    should "find the correct object" do
      assert_equal @object, @controller.send(:object)
    end
  end
  
  context "load object helper" do
    setup do
      @controller.send(:load_object)
    end
      
    should "load object as instance variable" do
      assert_equal @object, @controller.instance_variable_get("@post")
    end
    
    context "with an alternate object_name" do
      setup do
        @controller.stubs(:object_name).returns('asdf')
        @controller.send(:load_object)
      end

      should "use the variable name" do
        assert_equal @object, @controller.instance_variable_get("@asdf")
      end
    end
  end
  
  context "load_collection helper" do
    context "with resource_name" do
      setup do
        @controller.send(:load_collection)
      end

      should "load collection in to instance variable with plural model_name" do
        assert_equal @collection, @controller.instance_variable_get("@posts")
      end
    end
  end
  
  context "object params helper" do
    context "without alternate variable name" do
      setup do
        @params.expects(:[]).with("post").returns(2)
      end

      should "get params for object" do
        assert_equal 2, @controller.send(:object_params)
      end
    end
    
    context "with alternate object_name" do
      setup do
        @params.expects(:[]).with("something").returns(3)
        @controller.expects(:object_name).returns("something")
      end

      should "use variable name" do
        assert_equal 3, @controller.send(:object_params)
      end
    end
  end
  
  context "build object helper" do
    context "with no parents" do
      setup do
        Post.expects(:new).with("1").returns("a new post")
      end
    
      should "build new object" do
        assert_equal "a new post", @controller.send(:build_object)
      end
    end
    
    context "with parent" do
      setup do
        @comments_controller = CommentsController.new
        @comment_params = stub()
        @comment_params.stubs(:[]).with(:post_id).returns 2
        @comment_params.stubs(:[]).with('comment').returns ""
        @comments_controller.stubs(:params).returns(@comment_params)
        
        @request = stub :path => ""
        @comments_controller.stubs(:request).returns(@request)    
        
        Post.expects(:find).with(2).returns(Post.new)
        @comments = stub()
        @comments.expects(:build).with("").returns("a new comment")
        Post.any_instance.stubs(:comments).returns(@comments)
      end

      should "build new object" do
        assert_equal "a new comment", @comments_controller.send(:build_object)
      end
    end
  end
end
