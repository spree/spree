require File.dirname(__FILE__) + '/spec_helper'

class MockableClass
  def self.find id
    return :original_return
  end
end

describe "A partial mock" do

  it "should work at the class level (but fail here due to the type mismatch)" do
    MockableClass.should_receive(:find).with(1).and_return {:stub_return}
    MockableClass.find("1").should equal(:stub_return)
  end

  it "should revert to the original after each spec" do
    MockableClass.find(1).should equal(:original_return)
  end

end
