require File.dirname(__FILE__) + '/spec_helper'

describe "A consumer of a mock" do
  it "should be able to send messages to the mock" do
    mock = mock("poke me")
    mock.should_receive(:poke)
    mock.poke
  end
end

describe "a mock" do
  it "should be able to mock the same message twice w/ different args" do
    mock = mock("mock")
    mock.should_receive(:msg).with(:arg1).and_return(:val1)
    mock.should_receive(:msg).with(:arg2).and_return(:val2)
    mock.msg(:arg1).should eql(:val1)
    mock.msg(:arg2).should eql(:val2)
  end

  it "should be able to mock the same message twice w/ different args in reverse order" do
    mock = mock("mock")
    mock.should_receive(:msg).with(:arg1).and_return(:val1)
    mock.should_receive(:msg).with(:arg2).and_return(:val2)
    mock.msg(:arg2).should eql(:val2)
    mock.msg(:arg1).should eql(:val1)
  end
end
