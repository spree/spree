require File.dirname(__FILE__) + '/../spec_helper'

describe ProductGroup do

  context "validations" do
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:product_group) }
  end

end
