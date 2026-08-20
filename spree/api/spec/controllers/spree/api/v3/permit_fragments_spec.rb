require 'spec_helper'

RSpec.describe Spree::Api::V3::PermitFragments do
  describe '.merge' do
    it 'combines scalar attributes without duplicating them' do
      expect(described_class.merge([:name], [:brand_id, :name])).to eq([:name, :brand_id])
    end

    it 'leaves a list untouched when the other side is empty' do
      expect(described_class.merge([:name, { metadata: {} }], [])).to eq([:name, { metadata: {} }])
    end

    it 'unions two narrow filters for the same key' do
      merged = described_class.merge([{ prices: [:amount] }], [{ prices: [:currency] }])

      expect(merged).to eq([{ prices: [:amount, :currency] }])
    end

    it 'keeps the open hash when one side permits any nested key' do
      expect(described_class.merge([{ metadata: {} }], [{ metadata: [:ext] }])).to eq([{ metadata: {} }])
      expect(described_class.merge([{ metadata: [:ext] }], [{ metadata: {} }])).to eq([{ metadata: {} }])
    end

    it 'merges nested fragments recursively' do
      merged = described_class.merge(
        [{ variants: [:sku, { prices: [:amount] }] }],
        [{ variants: [{ prices: [:currency] }] }]
      )

      expect(merged).to eq([{ variants: [:sku, { prices: [:amount, :currency] }] }])
    end

    # The regression this exists for: plain concatenation lets the later
    # fragment replace the earlier one, so `metadata` would lose `core`.
    it 'preserves both sides through params.permit' do
      params = ActionController::Parameters.new(
        'name' => 'x',
        'metadata' => { 'core' => 'a', 'ext' => 'b' }
      )

      permitted = params.permit(
        *described_class.merge([:name, { metadata: {} }], [{ metadata: [:ext] }])
      )

      expect(permitted.to_h).to eq('name' => 'x', 'metadata' => { 'core' => 'a', 'ext' => 'b' })
    end
  end
end
