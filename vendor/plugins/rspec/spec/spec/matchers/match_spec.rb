require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should match(expected)" do
  it "should pass when target (String) matches expected (Regexp)" do
    "string".should match(/tri/)
  end

  it "should fail when target (String) does not match expected (Regexp)" do
    lambda {
      "string".should match(/rings/)
    }.should fail
  end
  
  it "should provide message, expected and actual on failure" do
    matcher = match(/rings/)
    matcher.matches?("string")
    matcher.failure_message.should == ["expected \"string\" to match /rings/", /rings/, "string"]
  end
end

describe "should_not match(expected)" do
  it "should pass when target (String) matches does not match (Regexp)" do
    "string".should_not match(/rings/)
  end

  it "should fail when target (String) matches expected (Regexp)" do
    lambda {
      "string".should_not match(/tri/)
    }.should fail
  end

  it "should provide message, expected and actual on failure" do
    matcher = match(/tri/)
    matcher.matches?("string")
    matcher.negative_failure_message.should == ["expected \"string\" not to match /tri/", /tri/, "string"]
  end
end
