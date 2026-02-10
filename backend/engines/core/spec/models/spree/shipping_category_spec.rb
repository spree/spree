require 'spec_helper'

describe Spree::ShippingCategory, type: :model do
  context 'Validations' do
    it 'has a valid factory' do
      expect(FactoryBot.build(:shipping_category)).to be_valid
    end

    it 'requires name' do
      expect(FactoryBot.build(:shipping_category, name: '')).not_to be_valid
    end

    it 'validates uniqueness' do
      FactoryBot.create(:shipping_category, name: 'Test')
      expect(FactoryBot.build(:shipping_category, name: 'Test')).not_to be_valid
    end
  end

  describe '#includes_digital_shipping_method?' do
    it 'returns true if the shipping category includes a digital shipping method' do
      shipping_category = create(:shipping_category)
      create(:shipping_method, shipping_categories: [shipping_category], calculator: create(:digital_shipping_calculator))
      expect(shipping_category.includes_digital_shipping_method?).to be_truthy
    end
  end
end
