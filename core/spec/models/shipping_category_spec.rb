require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingCategory do
  context "shoulda validations" do
    it { should validate_presence_of(:name) }
  end

  context "factory_girl" do
    specify { Factory(:shipping_category).new_record?.should be_false }
  end
end
