require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingCategory do

  context "validations" do
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:shipping_category) }
  end

end
