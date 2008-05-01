require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe Spec::Expectations, "#fail_with with no diff" do
  before(:each) do
    @old_differ = Spec::Expectations.differ
    Spec::Expectations.differ = nil
  end
  
  it "should handle just a message" do
    lambda {
      Spec::Expectations.fail_with "the message"
    }.should fail_with("the message")
  end
  
  it "should handle an Array" do
    lambda {
      Spec::Expectations.fail_with ["the message","expected","actual"]
    }.should fail_with("the message")
  end

  after(:each) do
    Spec::Expectations.differ = @old_differ
  end
end

describe Spec::Expectations, "#fail_with with diff" do
  before(:each) do
    @old_differ = Spec::Expectations.differ
    @differ = mock("differ")
    Spec::Expectations.differ = @differ
  end
  
  it "should not call differ if no expected/actual" do
    lambda {
      Spec::Expectations.fail_with "the message"
    }.should fail_with("the message")
  end
  
  it "should call differ if expected/actual are presented separately" do
    @differ.should_receive(:diff_as_string).and_return("diff")
    lambda {
      Spec::Expectations.fail_with "the message", "expected", "actual"
    }.should fail_with("the message\nDiff:diff")
  end
  
  it "should call differ if expected/actual are not strings" do
    @differ.should_receive(:diff_as_object).and_return("diff")
    lambda {
      Spec::Expectations.fail_with "the message", :expected, :actual
    }.should fail_with("the message\nDiff:diff")
  end
  
  it "should not call differ if expected or actual are procs" do
    @differ.should_not_receive(:diff_as_string)
    @differ.should_not_receive(:diff_as_object)
    lambda {
      Spec::Expectations.fail_with "the message", lambda {}, lambda {}
    }.should fail_with("the message")
  end
  
  it "should call differ if expected/actual are presented in an Array with message" do
    @differ.should_receive(:diff_as_string).with("actual","expected").and_return("diff")
    lambda {
      Spec::Expectations.fail_with(["the message", "expected", "actual"])
    }.should fail_with(/the message\nDiff:diff/)
  end
  
  after(:each) do
    Spec::Expectations.differ = @old_differ
  end
end
