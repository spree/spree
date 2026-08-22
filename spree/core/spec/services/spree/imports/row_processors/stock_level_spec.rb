require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::StockLevel do
  let(:store) { @default_store }
  let(:import) { create(:import, type: 'Spree::Imports::StockLevels', owner: store) }
  let(:stock_location) { create(:stock_location, store: store, name: 'Main Warehouse') }
  let(:product) { create(:product, store: store) }
  let(:variant) { create(:variant, product: product, sku: 'WIDGET-1') }

  before do
    stock_location
    variant.stock_levels.destroy_all
    create(:stock_level, variant: variant, stock_location: stock_location,
                        count_on_hand: 4, adjust_count_on_hand: false)
    variant.stock_levels.reload
  end

  def process(attributes)
    row = instance_double(Spree::ImportRow, import: import, to_schema_hash: attributes.stringify_keys)
    described_class.new(row).process!
  end

  def stock_level
    variant.stock_levels.find_by(stock_location: stock_location)
  end

  it 'sets the level the feed reports' do
    process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', count_on_hand: '11')

    expect(stock_level.reload.count_on_hand).to eq(11)
  end

  # An import that silently overwrote the number would leave a merchant unable
  # to answer "why did this change?".
  it 'leaves a movement behind so the change can be explained' do
    expect { process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', count_on_hand: '11') }.
      to change(Spree::StockMovement, :count).by(1)

    expect(Spree::StockMovement.last.quantity).to eq(7)
  end

  it 'accepts a relative adjustment from a feed that reports movements' do
    process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', adjustment: '-1')

    expect(stock_level.reload.count_on_hand).to eq(3)
  end

  it 'writes nothing when the level already matches' do
    expect { process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', count_on_hand: '4') }.
      not_to change(Spree::StockMovement, :count)
  end

  it 'finds the variant by the key the feeding system holds' do
    variant.set_external_id('erp', 'MAT-100')

    process(external_id: 'MAT-100', external_system: 'erp', stock_location: 'Main Warehouse', count_on_hand: '2')

    expect(stock_level.reload.count_on_hand).to eq(2)
  end

  it 'sets the backorder flag when the feed states it' do
    process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', count_on_hand: '4', backorderable: 'false')

    expect(stock_level.reload.backorderable).to be(false)
  end

  it 'creates the shelf when the variant has never been stocked there' do
    other = create(:stock_location, store: store, name: 'Overflow')

    process(sku: 'WIDGET-1', stock_location: 'Overflow', count_on_hand: '3')

    expect(variant.stock_levels.reload.find_by(stock_location: other).count_on_hand).to eq(3)
  end

  describe 'rows that name something unknown' do
    it 'says which SKU it could not find' do
      expect { process(sku: 'NOPE', stock_location: 'Main Warehouse', count_on_hand: '1') }.
        to raise_error(ArgumentError, /NOPE/)
    end

    # `to_i` reads "abc" as 0, which would empty a shelf on a typo.
    it 'refuses a count that is not a whole number rather than zeroing the shelf' do
      expect { process(sku: 'WIDGET-1', stock_location: 'Main Warehouse', count_on_hand: 'abc') }.
        to raise_error(ArgumentError, /count_on_hand must be a whole number/)
    end

    it 'says which location it could not find' do
      expect { process(sku: 'WIDGET-1', stock_location: 'Nowhere', count_on_hand: '1') }.
        to raise_error(ArgumentError, /Nowhere/)
    end

    it 'refuses a variant belonging to another store' do
      elsewhere = create(:variant, product: create(:product, store: create(:store)), sku: 'OTHER-1')
      elsewhere

      expect { process(sku: 'OTHER-1', stock_location: 'Main Warehouse', count_on_hand: '1') }.
        to raise_error(ArgumentError, /OTHER-1/)
    end
  end
end
