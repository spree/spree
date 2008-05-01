require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Example
    module ExampleMatcherSpecHelper
      class MatchDescription
        def initialize(description)
          @description = description
        end
        
        def matches?(matcher)
          matcher.matches?(@description)
        end
        
        def failure_message
          "expected matcher.matches?(#{@description.inspect}) to return true, got false"
        end
        
        def negative_failure_message
          "expected matcher.matches?(#{@description.inspect}) to return false, got true"
        end
      end
      def match_description(description)
        MatchDescription.new(description)
      end
    end

    describe ExampleMatcher, "#matches?" do
      include ExampleMatcherSpecHelper
      
      it "should match correct example_group and example" do
        matcher = ExampleMatcher.new("example_group", "example")
        matcher.should match_description("example_group example")
      end
      
      it "should not match wrong example" do
        matcher = ExampleMatcher.new("example_group", "other example")
        matcher.should_not match_description("example_group example")
      end
      
      it "should not match wrong example_group" do
        matcher = ExampleMatcher.new("other example_group", "example")
        matcher.should_not match_description("example_group example")
      end
      
      it "should match example only" do
        matcher = ExampleMatcher.new("example_group", "example")
        matcher.should match_description("example")
      end

      it "should match example_group only" do
        matcher = ExampleMatcher.new("example_group", "example")
        matcher.should match_description("example_group")
      end

      it "should match example_group ending with before(:all)" do
        matcher = ExampleMatcher.new("example_group", "example")
        matcher.should match_description("example_group before(:all)")
      end
      
      it "should escape regexp chars" do
        matcher = ExampleMatcher.new("(con|text)", "[example]")
        matcher.should_not match_description("con p")
      end
      
      it "should match when example_group is modularized" do
        matcher = ExampleMatcher.new("MyModule::MyClass", "example")
        matcher.should match_description("MyClass example")
      end      
    end

    describe ExampleMatcher, "#matches? normal case" do
      it "matches when passed in example matches" do
        matcher = ExampleMatcher.new("Foo", "bar")
        matcher.matches?(["no match", "Foo bar"]).should == true
      end

      it "does not match when no passed in examples match" do
        matcher = ExampleMatcher.new("Foo", "bar")
        matcher.matches?(["no match1", "no match2"]).should == false
      end
    end

    describe ExampleMatcher, "#matches? where description has '::' in it" do
      it "matches when passed in example matches" do
        matcher = ExampleMatcher.new("Foo::Bar", "baz")
        matcher.matches?(["no match", "Foo::Bar baz"]).should == true
      end

      it "does not match when no passed in examples match" do
        matcher = ExampleMatcher.new("Foo::Bar", "baz")
        matcher.matches?(["no match1", "no match2"]).should == false
      end
    end
  end
end
