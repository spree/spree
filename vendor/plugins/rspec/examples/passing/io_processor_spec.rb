require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/io_processor'
require 'stringio'

describe "An IoProcessor" do
  before(:each) do
    @processor = IoProcessor.new
  end

  it "should raise nothing when the file is exactly 32 bytes" do
    lambda {
      @processor.process(StringIO.new("z"*32))
    }.should_not raise_error
  end

  it "should raise an exception when the file length is less than 32 bytes" do
    lambda {
      @processor.process(StringIO.new("z"*31))
    }.should raise_error(DataTooShort)
  end
end
