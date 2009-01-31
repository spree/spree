require File.dirname(__FILE__) + '/../spec_helper'

describe CssPoint do
  before(:each) do
    @css_point = CssPoint.new
  end

  it "should be valid" do
    @css_point.should be_valid
  end
end
