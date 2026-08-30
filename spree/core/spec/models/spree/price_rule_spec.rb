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

  # Catalog assignment supersedes the audience rules, so pickers stop
  # offering them — but they are grandfathered, not removed. The context
  # rules stay unmarked.
  describe '.subclasses_with_preference_schema' do
    it 'flags only the superseded audience kinds' do
      entries = described_class.subclasses_with_preference_schema.index_by { |entry| entry[:type] }

      expect(entries['customer_group_rule'][:superseded]).to be true
      expect(entries['user_rule'][:superseded]).to be true
      expect(entries['channel_rule']).not_to have_key(:superseded)
      expect(entries['market_rule']).not_to have_key(:superseded)
      expect(entries['volume_rule']).not_to have_key(:superseded)
    end
  end
end
