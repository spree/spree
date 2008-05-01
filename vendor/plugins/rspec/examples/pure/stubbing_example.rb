require File.dirname(__FILE__) + '/spec_helper'

describe "A consumer of a stub" do
  it "should be able to stub methods on any Object" do
    obj = Object.new
    obj.stub!(:foobar).and_return {:return_value}
    obj.foobar.should equal(:return_value)
  end
end

class StubbableClass
  def self.find id
    return :original_return
  end
end

describe "A stubbed method on a class" do
  it "should return the stubbed value" do
    StubbableClass.stub!(:find).and_return(:stub_return)
    StubbableClass.find(1).should equal(:stub_return)
  end
  
  it "should revert to the original method after each spec" do
    StubbableClass.find(1).should equal(:original_return)
  end

  it "can stub! and mock the same message" do
    StubbableClass.stub!(:msg).and_return(:stub_value)
    StubbableClass.should_receive(:msg).with(:arg).and_return(:mock_value)

    StubbableClass.msg.should equal(:stub_value)
    StubbableClass.msg(:other_arg).should equal(:stub_value)
    StubbableClass.msg(:arg).should equal(:mock_value)
    StubbableClass.msg(:another_arg).should equal(:stub_value)
    StubbableClass.msg(:yet_another_arg).should equal(:stub_value)
    StubbableClass.msg.should equal(:stub_value)
  end
end

describe "A mock" do
  it "can stub!" do
    mock = mock("stubbing mock")
    mock.stub!(:msg).and_return(:value)
    (1..10).each {mock.msg.should equal(:value)}
  end
  
  it "can stub! and mock" do
    mock = mock("stubbing mock")
    mock.stub!(:stub_message).and_return(:stub_value)
    mock.should_receive(:mock_message).once.and_return(:mock_value)
    (1..10).each {mock.stub_message.should equal(:stub_value)}
    mock.mock_message.should equal(:mock_value)
    (1..10).each {mock.stub_message.should equal(:stub_value)}
  end
  
  it "can stub! and mock the same message" do
    mock = mock("stubbing mock")
    mock.stub!(:msg).and_return(:stub_value)
    mock.should_receive(:msg).with(:arg).and_return(:mock_value)
    mock.msg.should equal(:stub_value)
    mock.msg(:other_arg).should equal(:stub_value)
    mock.msg(:arg).should equal(:mock_value)
    mock.msg(:another_arg).should equal(:stub_value)
    mock.msg(:yet_another_arg).should equal(:stub_value)
    mock.msg.should equal(:stub_value)
  end
end

    
