require File.dirname(__FILE__)+'/../test_helper'

class HelpersTest < Test::Unit::TestCase
  
  def setup
    @controller = PostsController.new

    @params = stub :[] => "1"
    @controller.stubs(:params).returns(@params)

    @object = Post.new
    Post.stubs(:find).with("1").returns(@object)
    
    @collection = mock()
    Post.stubs(:find).with(:all).returns(@collection)
  end
  
  ResourceController::NAME_ACCESSORS.each do |accessor|
    context "#{accessor} accessor" do
      should "default to returning the singular name of the controller" do
        assert_equal "post", @controller.send(accessor)
      end
    end
  end
end
