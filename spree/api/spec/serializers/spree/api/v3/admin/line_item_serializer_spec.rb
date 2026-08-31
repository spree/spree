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

  # Feeds the order editor's negotiated-price comparison: what the catalog
  # charges, so a manual line can be shown against the price it replaced.
  describe 'catalog_price' do
    it 'reports the variant base price, independent of what the line was sold at' do
      line_item.update_columns(price: 7.2, price_source: 'manual')

      expect(subject['catalog_price']).to eq(line_item.variant.amount_in(line_item.currency).to_s)
      expect(subject['catalog_price']).not_to eq('7.2')
    end
  end

  describe 'price_source' do
    before { line_item.update_columns(price_source: 'manual') }

    it 'is exposed here and stays off the store serializer — provenance is operational' do
      expect(subject['price_source']).to eq('manual')

      store_result = Spree::Api::V3::LineItemSerializer.new(line_item, params: base_params).to_h
      expect(store_result).not_to have_key('price_source')
    end
  end

  # `seller_id` itself is covered on the store serializer this one extends.
  describe 'seller expand' do
    it 'resolves the operator view rather than the public profile' do
      seller = create(:seller, store: store)
      line_item.variant.product.update!(seller: seller)
      line_item.reload.save!

      result = described_class.new(
        line_item.reload, params: base_params.merge(expand: ['seller'])
      ).to_h

      expect(result['seller']['status']).to eq(seller.status)
    end
  end
end
