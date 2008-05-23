require File.dirname(__FILE__) + '/../spec_helper'

describe Gateway do
  before(:each) do
    @gateway = Gateway.new
  end

  it "should be valid" do
    @gateway.should be_valid
  end
end
