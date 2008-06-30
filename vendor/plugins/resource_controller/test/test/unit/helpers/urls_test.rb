require File.dirname(__FILE__)+'/../../test_helper'

class Helpers::UrlsTest < Test::Unit::TestCase
  def setup
    @controller = PostsController.new

    @params = stub :[] => "1"
    @controller.stubs(:params).returns(@params)

    @object = Post.new
    Post.stubs(:find).with("1").returns(@object)
    
    @collection = mock()
    Post.stubs(:find).with(:all).returns(@collection)
  end
  
  context "*_url_options helpers" do
    setup do
      @products_controller = ::Cms::ProductsController.new
      
      @products_controller.stubs(:params).returns(@params)

      @product = Product.new
      Product.stubs(:find).with("1").returns(@product)
    end
    
    should "return the correct collection options" do
      assert_equal [nil, :posts], @controller.send(:collection_url_options)
    end
    
    should "return the correct object options" do
      assert_equal [nil, nil, [:post, @object]], @controller.send(:object_url_options)
    end
    
    should "return the correct collection options for a namespaced controller" do
      assert_equal [:cms, nil, :products], @products_controller.send(:collection_url_options)
    end
    
    should "return the correct object options for a namespaced controller" do
      assert_equal [nil, :cms, nil, [:product, @product]], @products_controller.send(:object_url_options)
    end
    
    should "return the correct object options when passed an action" do
      assert_equal [:edit, :cms, nil, [:product, @product]], @products_controller.send(:object_url_options, :edit)
    end
    
    should "accept an alternate object when passed one" do
      p = Product.new
      assert_equal [nil, :cms, nil, [:product, p]], @products_controller.send(:object_url_options, nil, p)
    end
    
    context "with parent" do
      setup do
        @params = stub :parent_type => 'user'
        @user = mock
        @controller.expects(:parent_object).returns @user
        @controller.expects(:parent?).returns(true)
        @controller.expects(:parent_type).returns "user"
      end

      should "return the correct object options for object_url_options" do
        @controller.expects(:object).returns @object
        assert_equal [:edit, [:user, @user], [:post, @object]], @controller.send(:object_url_options, :edit)
      end
      
      should "return the correct object options for collection" do
        assert_equal [[:user, @user], :posts], @controller.send(:collection_url_options)
      end
    end
  end
end