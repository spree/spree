require 'spec_helper'

describe Spree::ProductProperty do

  context "validations" do
    it { should have_valid_factory(:product_property) }
  end

end
