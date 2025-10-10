require 'spec_helper'

describe Spree::V2::Storefront::VariantSerializer do
  subject { described_class.new(variant, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let!(:variant) { create(:variant, price: 10, compare_at_price: 15) }

  it 'returns expected attributes' do
    expect(subject[:data][:attributes]).to include(
      sku: variant.sku,
      barcode: variant.barcode,
      weight: variant.weight,
      height: variant.height,
      width: variant.width,
      depth: variant.depth,
      is_master: variant.is_master,
      options_text: variant.options_text,
      options: variant.options,
      public_metadata: variant.public_metadata,
      purchasable: variant.purchasable?,
      in_stock: variant.in_stock?,
      backorderable: variant.backorderable?,
      currency: currency,
      price: BigDecimal(10),
      display_price: '$10.00',
      compare_at_price: BigDecimal(15),
      display_compare_at_price: '$15.00'
    )
  end

  it 'returns expected relationships' do
    expect(subject[:data][:relationships]).to include(
      :product,
      :images,
      :option_values
    )
  end

  it 'returns correct type' do
    expect(subject[:data][:type]).to eq :variant
  end
end
