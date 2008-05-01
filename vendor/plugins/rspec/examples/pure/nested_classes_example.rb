require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/stack'

class StackExamples < Spec::ExampleGroup
  describe(Stack)
  before(:each) do
    @stack = Stack.new
  end
end

class EmptyStackExamples < StackExamples
  describe("when empty")
  it "should be empty" do
    @stack.should be_empty
  end
end

class AlmostFullStackExamples < StackExamples
  describe("when almost full")
  before(:each) do
    (1..9).each {|n| @stack.push n}
  end
  it "should be full" do
    @stack.should_not be_full
  end
end

class FullStackExamples < StackExamples
  describe("when full")
  before(:each) do
    (1..10).each {|n| @stack.push n}
  end
  it "should be full" do
    @stack.should be_full
  end
end