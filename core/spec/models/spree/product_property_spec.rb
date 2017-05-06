require 'spec_helper'

describe Spree::ProductProperty, type: :model do
  context 'Associations' do
    it { is_expected.to belong_to(:product).inverse_of(:product_properties).touch(true).class_name('Spree::Product') }
    it { is_expected.to belong_to(:property).inverse_of(:product_properties).class_name('Spree::Property') }
  end

  context 'Validations' do
    it { is_expected.to validate_presence_of(:property) }
    it { is_expected.to validate_presence_of(:value) }
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

  context 'ransackable_associations' do
    it { expect(Spree::ProductProperty.whitelisted_ransackable_associations).to include('property') }
  end
end
