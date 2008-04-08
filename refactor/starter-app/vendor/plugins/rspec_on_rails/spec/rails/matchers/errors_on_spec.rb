require File.dirname(__FILE__) + '/../../spec_helper'

describe "error_on" do
  it "should provide a message including the name of what the error is on" do
    have(1).error_on(:whatever).description.should == "should have 1 error on :whatever"
  end
end

describe "errors_on" do
  it "should provide a message including the name of what the error is on" do
    have(2).errors_on(:whatever).description.should == "should have 2 errors on :whatever"
  end
end
