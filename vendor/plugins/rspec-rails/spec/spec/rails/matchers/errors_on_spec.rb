require File.dirname(__FILE__) + '/../../../spec_helper'

describe "error_on" do
  it "should provide a description including the name of what the error is on" do
    have(1).error_on(:whatever).description.should == "should have 1 error on :whatever"
  end
  
  it "should provide a failure message including the number actually given" do
    lambda {
      [].should have(1).error_on(:whatever)
    }.should fail_with("expected 1 error on :whatever, got 0")
  end
end

describe "errors_on" do
  it "should provide a description including the name of what the error is on" do
    have(2).errors_on(:whatever).description.should == "should have 2 errors on :whatever"
  end
  
  it "should provide a failure message including the number actually given" do
    lambda {
      [1].should have(3).errors_on(:whatever)
    }.should fail_with("expected 3 errors on :whatever, got 1")
  end
end