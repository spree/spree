require 'spec_helper'

describe Spree::TaxExemption, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 2) }
  let(:line_item) { order.line_items.first }
  let(:other_line_item) { order.line_items.last }

  it 'requires a reason' do
    expect(described_class.new(reason_code: 'resale')).to be_valid
    expect(described_class.new).not_to be_valid
  end

  it 'is never persisted' do
    expect(described_class.new).not_to respond_to(:save)
  end

  describe '#covers_jurisdiction?' do
    it 'claims every jurisdiction without a country' do
      exemption = described_class.new(reason_code: 'resale')

      expect(exemption.covers_jurisdiction?('US', 'NY')).to be(true)
      expect(exemption.covers_jurisdiction?(nil, nil)).to be(true)
    end

    it 'claims a whole country without a state' do
      exemption = described_class.new(reason_code: 'resale', country_code: 'US')

      expect(exemption.covers_jurisdiction?('US', 'NY')).to be(true)
      expect(exemption.covers_jurisdiction?('us', nil)).to be(true)
      expect(exemption.covers_jurisdiction?('DE', nil)).to be(false)
    end

    it 'claims one state when it names one' do
      exemption = described_class.new(reason_code: 'resale', country_code: 'US', state_code: 'NY')

      expect(exemption.covers_jurisdiction?('US', 'NY')).to be(true)
      expect(exemption.covers_jurisdiction?('US', 'CA')).to be(false)
      expect(exemption.covers_jurisdiction?('US', nil)).to be(false)
    end
  end

  describe '#covers_item?' do
    it 'claims every item without overrides' do
      expect(described_class.new(reason_code: 'resale').covers_item?(line_item)).to be(true)
    end

    it 'carves out a line the buyer bought for their own use' do
      exemption = described_class.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(item_id: line_item.prefixed_id, exempt: false)]
      )

      expect(exemption.covers_item?(line_item)).to be(false)
      expect(exemption.covers_item?(other_line_item)).to be(true)
    end
  end

  describe '#reason_code_for' do
    it 'prefers the line override reason over the entry reason' do
      exemption = described_class.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(item_id: line_item.prefixed_id, reason_code: 'government')]
      )

      expect(exemption.reason_code_for(line_item)).to eq('government')
      expect(exemption.reason_code_for(other_line_item)).to eq('resale')
    end
  end

  # The failure this guards is silent and in the merchant's disfavour: an
  # override that cannot name its line is skipped by #covers_item?, which then
  # reports every line exempt — so a carve-out becomes a whole-order exemption.
  describe 'an override that cannot name its line' do
    it 'makes the entry invalid' do
      exemption = described_class.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(exempt: false)]
      )

      expect(exemption).not_to be_valid
      expect(exemption.errors[:item_overrides]).to be_present
    end

    it 'leaves an entry with no overrides at all valid — that claims the order' do
      expect(described_class.new(reason_code: 'resale')).to be_valid
    end

    # Stated so the widening is visible: this is what the validation prevents
    # from ever reaching a provider.
    it 'would otherwise report every line as covered' do
      exemption = described_class.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(exempt: false)]
      )

      expect(exemption.covers_item?(line_item)).to be(true)
    end
  end

  describe Spree::TaxExemption::ItemOverride do
    it 'requires the item it applies to' do
      expect(described_class.new(item_id: 'li_abc')).to be_valid
      expect(described_class.new).not_to be_valid
    end

    it 'is exempt unless it says otherwise' do
      expect(described_class.new(item_id: 'li_abc')).to be_exempt
      expect(described_class.new(item_id: 'li_abc', exempt: false)).not_to be_exempt
    end
  end
end
