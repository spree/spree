require File.dirname(__FILE__) + '/../../spec_helper.rb'

module ExampleExpectations
  
  class ArbitraryMatcher
    def initialize(*args, &block)
      if args.last.is_a? Hash
        @expected = args.last[:expected]
      end
      if block_given?
        @expected = block.call
      end
      @block = block
    end
    
    def matches?(target)
      @target = target
      return @expected == target
    end
    
    def with(new_value)
      @expected = new_value
      self
    end
    
    def failure_message
      "expected #{@expected}, got #{@target}"
    end
    
    def negative_failure_message
      "expected not #{@expected}, got #{@target}"
    end
  end
  
  class PositiveOnlyMatcher < ArbitraryMatcher
    undef negative_failure_message rescue nil
  end
  
  def arbitrary_matcher(*args, &block)
    ArbitraryMatcher.new(*args, &block)
  end
  
  def positive_only_matcher(*args, &block)
    PositiveOnlyMatcher.new(*args, &block)
  end
  
end

module Spec
  module Expectations
    describe ExpectationMatcherHandler do
      describe "#handle_matcher" do
        it "should ask the matcher if it matches" do
          matcher = mock("matcher")
          actual = Object.new
          matcher.should_receive(:matches?).with(actual).and_return(true)
          ExpectationMatcherHandler.handle_matcher(actual, matcher)
        end
      
        it "should explain when the matcher parameter is not a matcher" do
          begin
            nonmatcher = mock("nonmatcher")
            actual = Object.new
            ExpectationMatcherHandler.handle_matcher(actual, nonmatcher)
          rescue Spec::Expectations::InvalidMatcherError => e
          end

          e.message.should =~ /^Expected a matcher, got /
        end
        
        it "should return the match value" do
          matcher = mock("matcher")
          actual = Object.new
          matcher.should_receive(:matches?).with(actual).and_return(:this_value)
          ExpectationMatcherHandler.handle_matcher(actual, matcher).should == :this_value
        end
      end
    end

    describe NegativeExpectationMatcherHandler do
      describe "#handle_matcher" do
        it "should explain when matcher does not support should_not" do
          matcher = mock("matcher")
          matcher.stub!(:matches?)
          actual = Object.new
          lambda {
            NegativeExpectationMatcherHandler.handle_matcher(actual, matcher)
          }.should fail_with(/Matcher does not support should_not.\n/)
        end      
      
        it "should ask the matcher if it matches" do
          matcher = mock("matcher")
          actual = Object.new
          matcher.stub!(:negative_failure_message)
          matcher.should_receive(:matches?).with(actual).and_return(false)
          NegativeExpectationMatcherHandler.handle_matcher(actual, matcher)
        end
      
        it "should explain when the matcher parameter is not a matcher" do
          begin
            nonmatcher = mock("nonmatcher")
            actual = Object.new
            NegativeExpectationMatcherHandler.handle_matcher(actual, nonmatcher)
          rescue Spec::Expectations::InvalidMatcherError => e
          end

          e.message.should =~ /^Expected a matcher, got /
        end

        
        it "should return the match value" do
          matcher = mock("matcher")
          actual = Object.new
          matcher.should_receive(:matches?).with(actual).and_return(false)
          matcher.stub!(:negative_failure_message).and_return("ignore")
          NegativeExpectationMatcherHandler.handle_matcher(actual, matcher).should be_false
        end
      end
    end
    
    describe ExpectationMatcherHandler do
      include ExampleExpectations
      
      it "should handle submitted args" do
        5.should arbitrary_matcher(:expected => 5)
        5.should arbitrary_matcher(:expected => "wrong").with(5)
        lambda { 5.should arbitrary_matcher(:expected => 4) }.should fail_with("expected 4, got 5")
        lambda { 5.should arbitrary_matcher(:expected => 5).with(4) }.should fail_with("expected 4, got 5")
        5.should_not arbitrary_matcher(:expected => 4)
        5.should_not arbitrary_matcher(:expected => 5).with(4)
        lambda { 5.should_not arbitrary_matcher(:expected => 5) }.should fail_with("expected not 5, got 5")
        lambda { 5.should_not arbitrary_matcher(:expected => 4).with(5) }.should fail_with("expected not 5, got 5")
      end

      it "should handle the submitted block" do
        5.should arbitrary_matcher { 5 }
        5.should arbitrary_matcher(:expected => 4) { 5 }
        5.should arbitrary_matcher(:expected => 4).with(5) { 3 }
      end
  
      it "should explain when matcher does not support should_not" do
        lambda {
          5.should_not positive_only_matcher(:expected => 5)
        }.should fail_with(/Matcher does not support should_not.\n/)
      end


    end
  end
end
