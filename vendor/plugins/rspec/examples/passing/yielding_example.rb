require File.dirname(__FILE__) + '/spec_helper'

class MessageAppender
  
  def initialize(appendage)
    @appendage = appendage
  end
  
  def append_to(message)
    if_told_to_yield do
      message << @appendage
    end
  end
    
end

describe "a message expectation yielding to a block" do
  it "should yield if told to" do
    appender = MessageAppender.new("appended to")
    appender.should_receive(:if_told_to_yield).and_yield
    message = ""
    appender.append_to(message)
    message.should == "appended to"
  end

  it "should not yield if not told to" do
    appender = MessageAppender.new("appended to")
    appender.should_receive(:if_told_to_yield)
    message = ""
    appender.append_to(message)
    message.should == ""
  end
end