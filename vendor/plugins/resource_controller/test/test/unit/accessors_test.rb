require File.dirname(__FILE__)+'/../test_helper'

class AccessorsTest < Test::Unit::TestCase
  def setup
    PostsController.class_eval do
      extend ResourceController::Accessors
    end
  end
  
  context "scoping reader" do
    setup do
      PostsController.class_eval do
        class_scoping_reader :create, ResourceController::ActionOptions.new
      end
    end
  
    should "access create as usual" do
      PostsController.class_eval do
        create.flash "asdf"
      end
    
      assert_equal "asdf", PostsController.create.flash
    end
  
    should "scope to create object in a block" do
      PostsController.class_eval do
        create do
          flash "asdf"
        end
      end

      assert_equal "asdf", PostsController.create.flash 
    end
  end
  
  context "reader/writer method" do
    setup do
      PostsController.class_eval do
        reader_writer :flash
      end
      
      @controller = PostsController.new
    end

    should "set and get var" do
      @controller.flash "something"
      assert_equal "something", @controller.flash
    end
  end
  
  context "class reader/writer method" do
    setup do
      PostsController.class_eval do
        class_reader_writer :flash
      end
      
      @controller = PostsController.new
    end
    
    should "initialize var" do
      assert_nil PostsController.flash
      assert_nil @controller.flash
    end

    should "set and get var" do
      PostsController.flash "something"
      assert_equal "something", PostsController.flash
    end
  end
  
  context "block accessor" do
    setup do
      PostsController.class_eval do
        block_accessor :something
      end
      @controller = PostsController.new
    end

    should "store blocks" do
      @controller.something {}
      assert @controller.something.first
    end
    
    should "store symbols as well" do
      @controller.something(:method, :method_two) {}
      assert_equal :method,     @controller.something[0]
      assert_equal :method_two, @controller.something[1]
      assert @controller.something[2].is_a?(Proc)
    end
  end
end