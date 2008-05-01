require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should include(expected)" do
  it "should pass if target includes expected" do
    [1,2,3].should include(3)
    "abc".should include("a")
  end

  it "should fail if target does not include expected" do
    lambda {
      [1,2,3].should include(4)
    }.should fail_with("expected [1, 2, 3] to include 4")
    lambda {
      "abc".should include("d")
    }.should fail_with("expected \"abc\" to include \"d\"")
  end
end

describe "should include(with, multiple, args)" do
  it "should pass if target includes all items" do
    [1,2,3].should include(1,2,3)
  end

  it "should fail if target does not include any one of the items" do
    lambda {
      [1,2,3].should include(1,2,4)
    }.should fail_with("expected [1, 2, 3] to include 1, 2 and 4")
  end
end

describe "should_not include(expected)" do
  it "should pass if target does not include expected" do
    [1,2,3].should_not include(4)
    "abc".should_not include("d")
  end

  it "should fail if target includes expected" do
    lambda {
      [1,2,3].should_not include(3)
    }.should fail_with("expected [1, 2, 3] not to include 3")
    lambda {
      "abc".should_not include("c")
    }.should fail_with("expected \"abc\" not to include \"c\"")
  end
end
