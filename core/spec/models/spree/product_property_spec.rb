require 'spec_helper'

describe Spree::ProductProperty, type: :model do
  context 'touching' do
    it 'updates product' do
      pp = create(:product_property)
      expect(pp.product).to receive(:touch)
      pp.touch
    end
  end

  context 'property_name=' do
    before do
      @pp = create(:product_property)
    end

    it 'assigns property' do
      @pp.property_name = 'Size'
      expect(@pp.property.name).to eq('Size')
    end
  end

  context 'ransackable_associations' do
    it { expect(Spree::ProductProperty.whitelisted_ransackable_associations).to include('property') }
  end
end
