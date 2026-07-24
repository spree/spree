require 'spec_helper'

RSpec.describe Spree::Api::V3::LineItemSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:variant) { create(:variant, product: product) }
  let(:order) { create(:order, store: store) }
  let(:line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(line_item, params: base_params).to_h }

  describe 'serialized attributes' do
    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => line_item.prefixed_id,
        'variant_id' => variant.prefixed_id,
        'quantity' => 2,
        'currency' => 'USD',
        'name' => product.name,
        'slug' => product.slug
      )
    end

    it 'includes price attributes' do
      expect(subject).to have_key('price')
      expect(subject).to have_key('display_price')
      expect(subject).to have_key('total')
      expect(subject).to have_key('display_total')
    end

    it 'includes adjustment attributes' do
      expect(subject).to have_key('adjustment_total')
      expect(subject).to have_key('display_adjustment_total')
      expect(subject).to have_key('discount_total')
      expect(subject).to have_key('display_discount_total')
    end

    it 'includes tax attributes' do
      expect(subject).to have_key('additional_tax_total')
      expect(subject).to have_key('display_additional_tax_total')
      expect(subject).to have_key('included_tax_total')
      expect(subject).to have_key('display_included_tax_total')
    end

    it 'does not include timestamps in Store API' do
      expect(subject).not_to have_key('created_at')
      expect(subject).not_to have_key('updated_at')
    end

    it 'includes option_values array' do
      expect(subject['option_values']).to be_an(Array)
    end
  end

  describe 'nested adjustment lines' do
    let!(:tax_line) { create(:tax_line, line_item: line_item, order: order, amount: 2.0, label: 'VAT') }
    let!(:discount_line) { create(:discount_line, line_item: line_item, order: order, amount: -1.5) }

    it 'includes tax and discount lines' do
      expect(subject['tax_lines'].sole).to include('amount' => '2.0', 'label' => 'VAT', 'included' => false)
      expect(subject['discount_lines'].sole).to include('amount' => '-1.5')
    end

    it 'does not include line internals or timestamps' do
      expect(subject['tax_lines'].sole).not_to have_key('created_at')
      expect(subject['discount_lines'].sole).not_to have_key('promotion_action_id')
    end

    context 'when prices are hidden' do
      let(:base_params) { { store: store, currency: 'USD', hide_prices: true } }

      it 'omits the lines entirely' do
        expect(subject).not_to have_key('tax_lines')
        expect(subject).not_to have_key('discount_lines')
      end
    end
  end

  describe 'thumbnail_url' do
    context 'when variant has an image' do
      let(:image) { create(:image) }
      let(:variant) { create(:variant, product: product, images: [image]) }

      before do
        variant.update_thumbnail!
      end

      it 'returns the variant thumbnail URL' do
        expect(subject['thumbnail_url']).to be_present
        expect(subject['thumbnail_url']).to include(image.attachment.filename.to_s)
      end
    end

    context 'when variant has no image but product has an image' do
      let(:image) { create(:image) }
      let(:variant) { product.default_variant }

      before do
        product.images << image
        product.update_thumbnail!
      end

      it 'returns the product thumbnail URL' do
        expect(subject['thumbnail_url']).to be_present
        expect(subject['thumbnail_url']).to include(image.attachment.filename.to_s)
      end
    end

    context 'when neither variant nor product has an image' do
      it 'returns nil' do
        expect(subject['thumbnail_url']).to be_nil
      end
    end
  end

  it 'does not expose metadata in Store API responses' do
    line_item.update!(private_metadata: { 'gift_note' => 'Happy Birthday!' })
    expect(subject).not_to have_key('metadata')
    expect(subject).not_to have_key('private_metadata')
  end

  describe 'compare_at_amount' do
    context 'when variant has no compare_at_price' do
      it 'returns nil' do
        expect(subject['compare_at_amount']).to be_nil
      end
    end

    context 'when variant has compare_at_price' do
      before do
        variant.prices.first.update!(compare_at_amount: 29.99)
      end

      it 'returns the compare_at_amount as string' do
        expect(subject['compare_at_amount']).to be_present
      end
    end
  end
end
