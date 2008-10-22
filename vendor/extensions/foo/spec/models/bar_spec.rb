require File.dirname(__FILE__) + '/../spec_helper'

describe Bar do
  before(:each) do
    @bar = Bar.new
  end

  it "should be valid" do
    @bar.should be_valid
  end
end
