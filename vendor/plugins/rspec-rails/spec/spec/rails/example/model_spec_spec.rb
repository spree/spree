require File.dirname(__FILE__) + '/../../../spec_helper'

module Spec
  module Rails
    module Example
      describe ModelExampleGroup do
        it "should clear its name from the description" do
          group = describe("foo", :type => :model) do
            $nested_group = describe("bar") do
            end
          end
          group.description.to_s.should == "foo"
          $nested_group.description.to_s.should == "foo bar"
        end
      end
    end
  end
end