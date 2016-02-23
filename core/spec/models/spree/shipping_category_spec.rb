require 'spec_helper'

describe Spree::ShippingCategory, type: :model do

  describe '#validations' do
    it 'should have a valid factory' do
      expect(FactoryGirl.build(:shipping_category)).to be_valid
    end

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.allow_blank }
  end
end
