require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    class Fish
      def can_swim?(distance_in_yards)
        distance_in_yards < 1000
      end
    end
    
    describe "predicate_matcher[method_on_object] = matcher_method" do
      predicate_matchers[:swim] = :can_swim?
      it "should match matcher_method if method_on_object returns true" do
        swim(100).matches?(Fish.new).should be_true
      end
      it "should not match matcher_method if method_on_object returns false" do
        swim(10000).matches?(Fish.new).should be_false
      end
    end
  end
end
