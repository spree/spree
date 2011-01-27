require File.dirname(__FILE__) + '/../spec_helper'

describe ProductProperty do

  context "validations" do
    it { should have_valid_factory(:product_property) }
  end

end
