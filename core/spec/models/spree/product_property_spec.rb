require 'spec_helper'

describe Spree::ProductProperty, :type => :model do
  context "touching" do
    it "should update product" do
      pp = create(:product_property)
      expect(pp.product).to receive(:touch)
      pp.touch
    end
  end

  context 'property_name=' do
    before do
      @pp = create(:product_property)
    end

    it "should assign property" do
      @pp.property_name = "Size"
      expect(@pp.property.name).to eq('Size')
    end
  end
end
