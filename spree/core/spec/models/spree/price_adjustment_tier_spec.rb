require 'spec_helper'

describe Spree::PriceAdjustmentTier, type: :model do
  let(:catalog) { create(:catalog, store: @default_store) }
  let(:price_list) do
    create(:price_list, store: @default_store, catalog: catalog, price_adjustment_percentage: -5)
  end

  describe 'validations' do
    # Quantity 1 is the list's own column; a band there would be a second
    # answer to a question already answered.
    it 'refuses a band at or below one unit' do
      expect(build(:price_adjustment_tier, price_list: price_list, min_quantity: 1)).not_to be_valid
      expect(build(:price_adjustment_tier, price_list: price_list, min_quantity: 0)).not_to be_valid
      expect(build(:price_adjustment_tier, price_list: price_list, min_quantity: 2)).to be_valid
    end

    it 'refuses a second band at the same quantity' do
      create(:price_adjustment_tier, price_list: price_list, min_quantity: 10)

      expect(build(:price_adjustment_tier, price_list: price_list, min_quantity: 10)).not_to be_valid
    end

    it 'allows the same quantity on another list' do
      create(:price_adjustment_tier, price_list: price_list, min_quantity: 10)
      other = create(:price_list, store: @default_store, catalog: create(:catalog, store: @default_store))

      expect(build(:price_adjustment_tier, price_list: other, min_quantity: 10)).to be_valid
    end

    # The same bounds the list's own column carries: at -100 every derived
    # price is zero, and the decimal(6,3) column stops at 1000.
    it 'refuses a percentage the arithmetic or the column cannot hold' do
      band = ->(pct) { build(:price_adjustment_tier, price_list: price_list, min_quantity: 10, percentage: pct) }

      expect(band.call(-100)).not_to be_valid
      expect(band.call(1000)).not_to be_valid
      expect(band.call(-99.999)).to be_valid
      expect(band.call(999.999)).to be_valid
    end

    # A factor of exactly 1 makes the list decline to price the line, so a
    # band reading "no further discount here" would fall through to the next
    # list instead. Removing the band is how a ladder stops.
    it 'refuses a band of zero rather than accepting one that does nothing' do
      expect(build(:price_adjustment_tier, price_list: price_list, min_quantity: 10, percentage: 0)).not_to be_valid
    end

    # Replacing a full ladder marks the old bands for destruction and builds
    # the new ones, so a cap counting the database would see both halves.
    it 'lets a full ladder be replaced with one the same size' do
      (2..(described_class::MAXIMUM_TIERS_PER_LIST + 1)).each do |quantity|
        create(:price_adjustment_tier, price_list: price_list, min_quantity: quantity)
      end

      replacement = (100..(99 + described_class::MAXIMUM_TIERS_PER_LIST)).map do |quantity|
        { min_quantity: quantity, percentage: '-7' }
      end

      expect(price_list.update(price_adjustment_tiers: replacement)).to be(true)
      expect(price_list.reload.price_adjustment_tiers.count).to eq(described_class::MAXIMUM_TIERS_PER_LIST)
    end

    it 'still refuses a replacement one past the cap' do
      replacement = (100..(100 + described_class::MAXIMUM_TIERS_PER_LIST)).map do |quantity|
        { min_quantity: quantity, percentage: '-7' }
      end

      expect(price_list.update(price_adjustment_tiers: replacement)).to be(false)
    end

    it 'refuses a ladder past the cap' do
      (2..(described_class::MAXIMUM_TIERS_PER_LIST + 1)).each do |quantity|
        create(:price_adjustment_tier, price_list: price_list, min_quantity: quantity)
      end

      extra = build(:price_adjustment_tier, price_list: price_list, min_quantity: 500)

      expect(extra).not_to be_valid
      expect(extra.errors.messages[:base].first).to include('at most 10')
    end
  end

  describe 'ordering' do
    it 'reads the list\'s bands from the shallowest up' do
      create(:price_adjustment_tier, price_list: price_list, min_quantity: 50)
      create(:price_adjustment_tier, price_list: price_list, min_quantity: 10)

      expect(price_list.reload.price_adjustment_tiers.map(&:min_quantity)).to eq([10, 50])
    end
  end
end
