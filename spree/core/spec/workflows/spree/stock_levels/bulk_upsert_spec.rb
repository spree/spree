require 'spec_helper'

RSpec.describe Spree::StockLevels::BulkUpsert do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }
  let(:location) { store.stock_locations.first || create(:stock_location, store: store) }

  def level_for(variant, location, count)
    Spree::StockLevel.find_or_create_by!(variant: variant, stock_location: location) do |level|
      level.count_on_hand = count
    end
  end

  describe 'setting a figure' do
    it 'corrects the shelf to the count given' do
      level = level_for(variant, location, 5)

      result = described_class.call(store: store, rows: [
        { variant_id: variant.prefixed_id, stock_location_id: location.prefixed_id, count_on_hand: 40 }
      ])

      expect(result).to be_success
      expect(level.reload.count_on_hand).to eq(40)
    end

    it 'takes a raw id as well as a prefixed one' do
      level = level_for(variant, location, 5)

      described_class.call(store: store, rows: [
        { variant_id: variant.id, stock_location_id: location.id, count_on_hand: 12 }
      ])

      expect(level.reload.count_on_hand).to eq(12)
    end

    # Stock changes are recorded as movements so a merchant can see why a
    # figure changed; writing the column straight would leave a hole.
    it 'records the change as a movement' do
      level = level_for(variant, location, 5)

      expect {
        described_class.call(store: store, rows: [
          { variant_id: variant.prefixed_id, stock_location_id: location.prefixed_id, count_on_hand: 40 }
        ])
      }.to change { level.reload.stock_movements.count }.by(1)
    end
  end

  # The scoping lives here rather than in the one controller that used to do
  # it: a row reaching `find_or_initialize_by` unscoped writes to whichever
  # shelf the id names, including another merchant's.
  describe 'a row naming another store' do
    let(:other_store) { create(:store, code: "other-#{SecureRandom.hex(4)}") }

    it 'leaves their shelf alone' do
      theirs = create(:product, store: other_store).variants.first || create(:variant, product: create(:product, store: other_store))
      their_location = create(:stock_location, store: other_store)
      their_level = level_for(theirs, their_location, 7)

      result = described_class.call(store: store, rows: [
        { variant_id: theirs.prefixed_id, stock_location_id: their_location.prefixed_id, count_on_hand: 999 }
      ])

      expect(result).to be_success
      expect(result.value[:stock_level_count]).to eq(0)
      expect(their_level.reload.count_on_hand).to eq(7)
    end

    it 'applies the rows that are ours and skips the rest' do
      ours = level_for(variant, location, 1)
      theirs = create(:product, store: other_store).variants.first || create(:variant, product: create(:product, store: other_store))

      result = described_class.call(store: store, rows: [
        { variant_id: variant.prefixed_id, stock_location_id: location.prefixed_id, count_on_hand: 20 },
        { variant_id: theirs.prefixed_id, stock_location_id: location.prefixed_id, count_on_hand: 999 }
      ])

      expect(result.value[:stock_level_count]).to eq(1)
      expect(ours.reload.count_on_hand).to eq(20)
    end
  end

  describe 'nothing to do' do
    it 'succeeds with no rows' do
      expect(described_class.call(store: store, rows: [])).to be_success
    end

    it 'ignores a row naming no variant' do
      result = described_class.call(store: store, rows: [{ count_on_hand: 5 }])

      expect(result.value[:stock_level_count]).to eq(0)
    end
  end
end
