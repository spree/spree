require File.dirname(__FILE__) + '/test_unit_spec_helper'

describe "Test::Unit::TestCase" do
  include TestUnitSpecHelper
  
  before(:each) do
    @dir = File.dirname(__FILE__) + "/resources"
  end
  
  describe "with passing test case" do
    it "should output 0 failures" do
      output = ruby("#{@dir}/test_case_that_passes.rb")
      output.should include("1 example, 0 failures")
    end

    it "should return an exit code of 0" do
      ruby("#{@dir}/test_case_that_passes.rb")
      $?.should == 0
    end
  end

  describe "with failing test case" do
    it "should output 1 failure" do
      output = ruby("#{@dir}/test_case_that_fails.rb")
      output.should include("1 example, 1 failure")
    end

    it "should return an exit code of 256" do
      ruby("#{@dir}/test_case_that_fails.rb")
      $?.should == 256
    end
  end

  describe "with test case that raises an error" do
    it "should output 1 failure" do
      output = ruby("#{@dir}/test_case_with_errors.rb")
      output.should include("1 example, 1 failure")
    end

    it "should return an exit code of 256" do
      ruby("#{@dir}/test_case_with_errors.rb")
      $?.should == 256
    end
  end
  
  describe "not yet implemented examples:" do
    it "this example should be reported as pending (not an error)"
  end
end