require File.dirname(__FILE__) + '/../spec_helper'

describe GatewayOption do
  before(:each) do
    @gateway_option = GatewayOption.new
  end

  it "should be valid" do
    @gateway_option.should be_valid
  end
end
