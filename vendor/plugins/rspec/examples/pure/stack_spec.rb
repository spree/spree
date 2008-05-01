require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + "/stack"
require File.dirname(__FILE__) + '/shared_stack_examples'

describe Stack, " (empty)" do
  before(:each) do
    @stack = Stack.new
  end
  
  # NOTE that this one auto-generates the description "should be empty"
  it { @stack.should be_empty }
  
  it_should_behave_like "non-full Stack"
  
  it "should complain when sent #peek" do
    lambda { @stack.peek }.should raise_error(StackUnderflowError)
  end
  
  it "should complain when sent #pop" do
    lambda { @stack.pop }.should raise_error(StackUnderflowError)
  end
end

describe Stack, " (with one item)" do
  before(:each) do
    @stack = Stack.new
    @stack.push 3
    @last_item_added = 3
  end

  it_should_behave_like "non-empty Stack"
  it_should_behave_like "non-full Stack"

end

describe Stack, " (with one item less than capacity)" do
  before(:each) do
    @stack = Stack.new
    (1..9).each { |i| @stack.push i }
    @last_item_added = 9
  end
  
  it_should_behave_like "non-empty Stack"
  it_should_behave_like "non-full Stack"
end

describe Stack, " (full)" do
  before(:each) do
    @stack = Stack.new
    (1..10).each { |i| @stack.push i }
    @last_item_added = 10
  end

  # NOTE that this one auto-generates the description "should be full"
  it { @stack.should be_full }  

  it_should_behave_like "non-empty Stack"

  it "should complain on #push" do
    lambda { @stack.push Object.new }.should raise_error(StackOverflowError)
  end
  
end
