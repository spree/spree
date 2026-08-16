require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::LineItemSerializer do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:line_item) { create(:line_item, order: order) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(line_item, params: base_params).to_h }

  describe 'metadata' do
    context 'when line item has metadata' do
      before { line_item.update!(metadata: { 'gift_note' => 'Happy Birthday!', 'engraving' => 'J.D.' }) }

      it 'returns the metadata' do
        expect(subject['metadata']).to eq({ 'gift_note' => 'Happy Birthday!', 'engraving' => 'J.D.' })
      end
    end

    context 'when line item has no metadata' do
      it 'returns empty hash' do
        expect(subject['metadata']).to eq({})
      end
    end
  end

  it 'inherits all store line item attributes' do
    expect(subject).to have_key('id')
    expect(subject).to have_key('variant_id')
    expect(subject).to have_key('quantity')
    expect(subject).to have_key('price')
    expect(subject).to have_key('total')
  end

  # `vendor_id` itself is covered on the store serializer this one extends.
  describe 'vendor expand' do
    it 'resolves the operator view rather than the public profile' do
      vendor = create(:vendor, store: store)
      line_item.update!(vendor: vendor)

      result = described_class.new(
        line_item.reload, params: base_params.merge(expand: ['vendor'])
      ).to_h

      expect(result['vendor']['status']).to eq(vendor.status)
    end
  end
end
