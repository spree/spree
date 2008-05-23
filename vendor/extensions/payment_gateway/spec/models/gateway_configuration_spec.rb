require File.dirname(__FILE__) + '/../spec_helper'

describe GatewayConfigruation do
  before(:each) do
    @gateway_configruation = GatewayConfigruation.new
  end

  it "should be valid" do
    @gateway_configruation.should be_valid
  end
end
