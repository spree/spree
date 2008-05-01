require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    class GrandParentExampleGroup < Spec::Example::ExampleGroup
      describe "Grandparent ExampleGroup"
    end

    class ParentExampleGroup < GrandParentExampleGroup
      describe "Parent ExampleGroup"
      it "should bar" do
      end
    end

    class ChildExampleGroup < ParentExampleGroup
      describe "Child ExampleGroup"
      it "should bam" do
      end
    end

    describe ChildExampleGroup do

    end
  end
end
