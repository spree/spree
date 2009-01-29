require File.dirname(__FILE__) + '/../spec_helper'

describe Theme do
  before(:each) do
    @theme = Theme.new
  end

  it "should be valid" do
    @theme.should be_valid
  end
end
