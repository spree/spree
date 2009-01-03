require File.dirname(__FILE__) + '/test_unit_spec_helper'

describe "ExampleGroup with test/unit/interop" do
  include TestUnitSpecHelper
    
  describe "with passing examples" do
    it "should output 0 failures" do
      output = ruby("#{resources}/spec_that_passes.rb")
      output.should include("1 example, 0 failures")
    end

    it "should return an exit code of 0" do
      ruby("#{resources}/spec_that_passes.rb")
      $?.should == 0
    end
  end

  describe "with failing examples" do
    it "should output 1 failure" do
      output = ruby("#{resources}/spec_that_fails.rb")
      output.should include("1 example, 1 failure")
    end

    it "should return an exit code of 256" do
      ruby("#{resources}/spec_that_fails.rb")
      $?.should == 256
    end
  end

  describe "with example that raises an error" do
    it "should output 1 failure" do
      output = ruby("#{resources}/spec_with_errors.rb")
      output.should include("1 example, 1 failure")
    end

    it "should return an exit code of 256" do
      ruby("#{resources}/spec_with_errors.rb")
      $?.should == 256
    end
  end
  
  describe "options hash" do
    it "should be exposed" do
      output = ruby("#{resources}/spec_with_options_hash.rb")
      output.should include("1 example, 0 failures")
    end
  end
end