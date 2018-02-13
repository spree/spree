require 'spec_helper'

describe Spree::ShippingCategory, type: :model do
  describe '#validations' do
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
end
