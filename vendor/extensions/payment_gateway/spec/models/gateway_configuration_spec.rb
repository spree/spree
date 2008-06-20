require File.dirname(__FILE__) + '/../spec_helper'

describe GatewayConfiguration do
  before(:each) do
    @gateway_configruation = GatewayConfiguration.new
  end

  it "should be valid" do
    @gateway_configruation.should be_valid
  end
end
