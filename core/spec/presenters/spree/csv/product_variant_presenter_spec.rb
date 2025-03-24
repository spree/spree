require 'spec_helper'

RSpec.describe Spree::CSV::ProductVariantPresenter do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store], width: 10, height: 15, depth: 20, dimensions_unit: 'in', weight_unit: 'lb') }
  let(:variant) { product.master }
  let(:properties) { [] }
  let(:taxons) { [] }
  let(:presenter) { described_class.new(product, variant, 0, 3, 3, properties, taxons, store) }

  let!(:variant_images) { create_list(:image, 3, viewable: variant) }

  let!(:variant_images) { create_list(:image, 3, viewable: variant) }

  describe '#call' do
    subject { presenter.call }

    it 'returns array with correct values' do
      expect(subject[0]).to eq product.id
      expect(subject[1]).to eq variant.sku
      expect(subject[2]).to eq variant.barcode
      expect(subject[3]).to eq product.name
      expect(subject[4]).to eq product.slug
      expect(subject[5]).to eq product.status
      expect(subject[6]).to eq product.try(:vendor_name)
      expect(subject[7]).to eq product.brand_name
      expect(subject[8]).to eq product.description&.html_safe
      expect(subject[9]).to eq product.meta_title
      expect(subject[10]).to eq product.meta_description
      expect(subject[11]).to eq product.meta_keywords
      expect(subject[12]).to eq product.tag_list.to_s
      expect(subject[13]).to eq product.label_list.to_s
      expect(subject[14]).to eq variant.amount_in(store.default_currency).to_f
      expect(subject[15]).to eq variant.compare_at_price&.to_f
      expect(subject[16]).to eq store.default_currency
      expect(subject[17]).to eq variant.width
      expect(subject[18]).to eq variant.height
      expect(subject[19]).to eq variant.depth
      expect(subject[20]).to eq 'in'
      expect(subject[21]).to eq variant.weight
      expect(subject[22]).to eq 'lb'
      expect(subject[23]).to eq variant.available_on&.strftime('%Y-%m-%d %H:%M:%S')
      expect(subject[24]).to eq variant.discontinue_on&.strftime('%Y-%m-%d %H:%M:%S')
      expect(subject[25]).to eq(variant.total_on_hand == BigDecimal::INFINITY ? '∞' : variant.total_on_hand)
      expect(subject[26]).to eq variant.backorderable?
      expect(subject[27]).to eq variant.tax_category&.name
      expect(subject[28]).to eq variant.digital?
      expect(subject[29]).to eq variant.images[0].original_url
      expect(subject[30]).to eq variant.images[1].original_url
      expect(subject[31]).to eq variant.images[2].original_url
    end

    context 'when index is not zero' do
      let(:variant) { create(:variant, product: product) }
      let(:presenter) { described_class.new(product, variant, 1, 3, 3, properties, taxons, store) }

      it 'returns nil for product-level fields' do
        expect(subject[3]).to be_nil # name
        expect(subject[4]).to be_nil # slug
        expect(subject[5]).to be_nil # status
        expect(subject[6]).to be_nil # vendor_name
      end

      it 'returns variant specific fields' do
        expect(subject[1]).to eq variant.sku
        expect(subject[14]).to eq variant.amount_in(store.default_currency).to_f
      end
    end
  end

  describe '#option_type' do
    let(:option_type) { create(:option_type) }

    before { product.option_types << option_type }

    it 'returns option type at given index' do
      expect(presenter.option_type(0)).to eq option_type
    end

    it 'returns nil for non-existent index' do
      expect(presenter.option_type(99)).to be_nil
    end
  end

  describe '#option_value' do
    let(:option_type) { create(:option_type) }
    let(:option_value) { create(:option_value, option_type: option_type) }

    before do
      product.option_types << option_type
      variant.option_values << option_value
    end

    it 'returns option value name for given option type' do
      expect(presenter.option_value(option_type)).to eq option_value.name
    end

    it 'returns nil for option type without value' do
      expect(presenter.option_value(create(:option_type))).to be_nil
    end
  end
end
