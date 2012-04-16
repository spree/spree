require 'spec_helper'

describe Spree::ShippingCategory do

  context "validations" do
    it { should have_valid_factory(:shipping_category) }
  end

end
