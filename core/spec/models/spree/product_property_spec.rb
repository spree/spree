require 'spec_helper'

describe Spree::ProductProperty, :type => :model do

  context "validations" do
    it "should validate length of value" do
      pp = create(:product_property)
      pp.value = "x" * 256
      expect(pp).not_to be_valid
    end
  end

  context "touching" do
    it "should update product" do
      pp = create(:product_property)
      expect(pp.product).to receive(:touch)
      pp.touch
    end
  end
end
