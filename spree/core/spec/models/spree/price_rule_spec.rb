require 'spec_helper'

describe Spree::PriceRule, type: :model do
  let(:price_list) { create(:price_list) }

  describe 'uniqueness of type per price_list' do
    it 'allows two rules of different types on the same list' do
      create(:market_price_rule, price_list: price_list)
      other = build(:customer_group_price_rule, price_list: price_list)
      expect(other).to be_valid
    end

    it 'rejects a second rule of the same type on the same list' do
      create(:market_price_rule, price_list: price_list)
      duplicate = build(:market_price_rule, price_list: price_list)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:type]).to be_present
    end

    it 'allows the same rule type on a different list' do
      create(:market_price_rule, price_list: price_list)
      other_list = create(:price_list)
      other = build(:market_price_rule, price_list: other_list)
      expect(other).to be_valid
    end
  end
end
