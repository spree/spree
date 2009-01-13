require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Example
    class ExampleGroupSubclass < ExampleGroup
      def self.examples_ran
        @examples_ran
      end

      def self.examples_ran=(examples_ran)
        @examples_ran = examples_ran
      end

      @@class_variable = :class_variable
      CONSTANT = :constant

      before do
        @instance_variable = :instance_variable
      end
      
      after(:all) do
        self.class.examples_ran = true
      end

      it "should have access to instance variables" do
        @instance_variable.should == :instance_variable
      end

      it "should have access to class variables" do
        @@class_variable.should == :class_variable
      end

      it "should have access to constants" do
        CONSTANT.should == :constant
      end

      it "should have access to methods defined in the Example Group" do
        a_method.should == 22
      end
      
      def a_method
        22
      end
    end

    describe ExampleGroupSubclass do
      it "should run" do
        ExampleGroupSubclass.examples_ran.should be_true
      end
    end
  end
end