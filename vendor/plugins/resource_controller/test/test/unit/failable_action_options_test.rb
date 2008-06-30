require File.dirname(__FILE__)+'/../test_helper'

class FailableActionOptionsTest < Test::Unit::TestCase
  def setup
    @controller = PostsController.new
    @create = ResourceController::FailableActionOptions.new
  end
  
  should "have success and fails" do
    assert ResourceController::ActionOptions, @create.success.class
    assert ResourceController::ActionOptions, @create.fails.class
  end
  
  %w(before).each do |accessor|
    should "have a block accessor for #{accessor}" do
      @create.send(accessor) do
        "return_something"
      end
    
      assert_equal "return_something", @create.send(accessor).first.call(nil)
    end
  end
  
  should "delegate flash to success" do
    @create.flash "Successfully created."
    assert_equal "Successfully created.", @create.success.flash
  end
  
  should "delegate after to success" do
    @create.after do
      "something"
    end
    
    assert_equal "something", @create.success.after.first.call
  end
  
  should "delegate response to success" do
    @create.response do |wants|
      wants.html
    end
    
    assert @create.wants[:html]
  end
  
  should "delegate wants to success" do
    @create.wants.html
    
    assert @create.wants[:html]
  end
  
  context "duplication" do
    setup do
      @opts = ResourceController::FailableActionOptions.new
      @opts.wants.js
      @opts.failure.wants.js
      @opts.before {}
      
      @dup = @opts.dup
    end

    should "duplicate success" do
      assert !@dup.success.equal?(@opts.success)
      assert @dup.success.wants[:js]
    end
    
    should "duplicate failure" do
      assert !@dup.failure.equal?(@opts.failure)
      assert @dup.failure.wants[:js]
    end
    
    should "duplicate before" do
      assert !@dup.before.equal?(@opts.before)
      assert @dup.before
    end
  end
  
end