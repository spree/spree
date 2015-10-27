require 'spec_helper'

describe Spree::ProductProperty, :type => :model do
  describe '#validations' do
    it { is_expected.to validate_presence_of(:product) }
    it { is_expected.to validate_presence_of(:property) }
    it { is_expected.to validate_uniqueness_of(:property_id).scoped_to(:product_id).with_message(:already_linked) }
  end

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
