require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingCategory do
  before(:each) do
    @shipping_category = ShippingCategory.new
  end

  it "should be valid" do
    @shipping_category.should be_valid
  end
end
