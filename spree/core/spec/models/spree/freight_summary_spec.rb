require 'spec_helper'

RSpec.describe Spree::FreightSummary do
  let(:store) { @default_store }
  let(:carton) { create(:carton_package_type, store: store, length: 40, width: 30, height: 25) }

  # 40 x 30 x 25 cm = 0.03 CBM per carton.
  let(:packed_variant) do
    create(:variant,
           units_per_carton: 12,
           cartons_per_pallet: 40,
           carton_weight: 10,
           weight_unit: 'kg',
           carton_package_type: carton)
  end

  def summary_for(pairs)
    contents = pairs.map do |variant, quantity|
      Spree::Stock::ContentItem.new(build(:inventory_unit, variant: variant, quantity: quantity))
    end

    described_class.build(contents)
  end

  describe 'a fully packed cart' do
    subject(:summary) { summary_for([[packed_variant, 24]]) }

    it 'counts units, cartons and pallets along the packing chain' do
      expect(summary.total_units).to eq(24)
      expect(summary.total_cartons).to eq(2)
      expect(summary.total_pallets).to eq(1)
    end

    it 'measures volume from the carton, not the loose goods' do
      expect(summary.total_volume).to eq(BigDecimal('0.06'))
    end

    it 'weighs the packed cartons' do
      expect(summary.total_weight).to eq(BigDecimal('20'))
    end

    it 'reports itself complete' do
      expect(summary).to be_complete
    end
  end

  it 'rounds a part carton up, because a part carton still ships as one' do
    expect(summary_for([[packed_variant, 13]]).total_cartons).to eq(2)
  end

  describe 'a variant with no carton' do
    let(:loose_variant) do
      create(:variant, width: 10, height: 10, depth: 10, dimensions_unit: 'cm', weight: 2, weight_unit: 'kg')
    end

    subject(:summary) { summary_for([[loose_variant, 3]]) }

    it 'falls back to the goods own measurements' do
      expect(summary.total_volume).to eq(BigDecimal('0.003'))
      expect(summary.total_weight).to eq(BigDecimal('6'))
    end

    it 'counts no cartons' do
      expect(summary.total_cartons).to eq(0)
    end

    # The numbers stay usable; the flag says why they are partial.
    it 'reports itself incomplete' do
      expect(summary).not_to be_complete
    end
  end

  it 'is incomplete when any single line is unmeasured' do
    loose = create(:variant, width: 10, height: 10, depth: 10, dimensions_unit: 'cm')

    expect(summary_for([[packed_variant, 12], [loose, 1]])).not_to be_complete
  end

  describe 'pallet counting' do
    it 'reports nothing when a carton-bearing line does not say how it stacks' do
      unstacked = create(:variant, units_per_carton: 6, carton_package_type: carton, cartons_per_pallet: nil)

      expect(summary_for([[packed_variant, 12], [unstacked, 6]]).total_pallets).to be_nil
    end

    it 'reports nothing when nothing is packed in cartons at all' do
      loose = create(:variant, width: 10, height: 10, depth: 10)

      expect(summary_for([[loose, 2]]).total_pallets).to be_nil
    end
  end

  # A client prints these strings beside "CBM" and "kg". BigDecimal's
  # default renders 0.06 as "0.6e-1".
  describe 'the serialized numbers' do
    it 'writes plain decimals, never engineering notation' do
      json = summary_for([[packed_variant, 24]]).as_json

      expect(json['total_volume']).to eq('0.06')
      expect(json['lines'].first['volume']).to eq('0.06')
    end
  end

  # The merchant recorded what a packed carton weighs. That is a better
  # answer than the loose goods' weight even when nobody measured the
  # carton's sides.
  it 'uses a declared carton weight even when the carton is unmeasured' do
    unmeasured_carton = create(:package_type, store: store, kind: 'carton', length: nil, width: nil, height: nil)
    variant = create(:variant, units_per_carton: 12, carton_weight: 10, weight_unit: 'kg',
                               weight: 0.2, carton_package_type: unmeasured_carton)

    summary = summary_for([[variant, 24]])

    expect(summary.total_weight).to eq(BigDecimal('20'))
    expect(summary).not_to be_complete
  end

  describe 'freezing and rebuilding' do
    it 'round-trips through its serialized form' do
      original = summary_for([[packed_variant, 24]])
      rebuilt = described_class.from_metadata(original.as_json)

      expect(rebuilt.total_units).to eq(original.total_units)
      expect(rebuilt.total_cartons).to eq(original.total_cartons)
      expect(rebuilt.total_pallets).to eq(original.total_pallets)
      expect(rebuilt.total_volume).to eq(original.total_volume)
      expect(rebuilt.total_weight).to eq(original.total_weight)
      expect(rebuilt).to be_complete
    end

    it 'answers nil for an absent snapshot' do
      expect(described_class.from_metadata(nil)).to be_nil
    end
  end

  describe 'having nothing to report' do
    it 'is empty for a cart with nothing in it' do
      expect(summary_for([])).to be_empty
    end

    # A retail catalog nobody measured would otherwise report a shipment of
    # zero cartons taking up no space, which reads as a measured empty load
    # rather than an unmeasured one.
    it 'is empty when the goods carry no measurements at all' do
      unmeasured = create(:variant, width: nil, height: nil, depth: nil, weight: 0)

      expect(summary_for([[unmeasured, 3]])).to be_empty
    end

    it 'is not empty once anything is measured' do
      measured = create(:variant, width: 10, height: 10, depth: 10, dimensions_unit: 'cm')

      expect(summary_for([[measured, 1]])).not_to be_empty
    end
  end
end
