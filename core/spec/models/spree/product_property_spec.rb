require 'spec_helper'

describe Spree::ProductProperty, :type => :model do
  context "touching" do
    it "should update product" do
      pp = create(:product_property)
      expect(pp.product).to receive(:touch)
      pp.touch
    end
  end
end
