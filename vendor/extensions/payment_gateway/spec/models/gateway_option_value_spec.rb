require File.dirname(__FILE__) + '/../spec_helper'

describe GatewayOptionValue do
  before(:each) do
    @gateway_option_value = GatewayOptionValue.new
  end

  it "should be valid" do
    @gateway_option_value.should be_valid
  end
end
