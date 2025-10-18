require 'spec_helper'

RSpec.describe Spree::CSV::ProductVariantPresenter do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store], width: 10, height: 15, depth: 20, dimensions_unit: 'in', weight_unit: 'lb') }
  let(:variant) { product.master }
  let(:properties) { [] }
  let(:taxons) { [] }
  let(:metafields) { [] }
  let(:presenter) { described_class.new(product, variant, 0, properties, taxons, store, metafields) }

  let!(:variant_images) { create_list(:image, 3, viewable: variant) }

  describe '#call' do
    subject { presenter.call }

    it 'returns array with correct values' do
      expect(subject[0]).to eq product.id
      expect(subject[1]).to eq variant.sku
      expect(subject[2]).to eq product.name
      expect(subject[3]).to eq product.slug
      expect(subject[4]).to eq product.status
      expect(subject[5]).to eq product.try(:vendor_name)
      expect(subject[6]).to eq product.brand_name
      expect(subject[7]).to eq product.description&.html_safe
      expect(subject[8]).to eq product.meta_title
      expect(subject[9]).to eq product.meta_description
      expect(subject[10]).to eq product.meta_keywords
      expect(subject[11]).to eq product.tag_list.to_s
      expect(subject[12]).to eq product.label_list.to_s
      expect(subject[13]).to eq variant.amount_in(store.default_currency).to_f
      expect(subject[14]).to eq variant.compare_at_amount_in(store.default_currency).to_f
      expect(subject[15]).to eq store.default_currency
      expect(subject[16]).to eq variant.width
      expect(subject[17]).to eq variant.height
      expect(subject[18]).to eq variant.depth
      expect(subject[19]).to eq 'in'
      expect(subject[20]).to eq variant.weight
      expect(subject[21]).to eq 'lb'
      expect(subject[22]).to eq variant.available_on&.strftime('%Y-%m-%d %H:%M:%S')
      expect(subject[23]).to eq variant.discontinue_on&.strftime('%Y-%m-%d %H:%M:%S')
      expect(subject[24]).to eq variant.track_inventory?
      expect(subject[25]).to eq(variant.total_on_hand == BigDecimal::INFINITY ? '∞' : variant.total_on_hand)
      expect(subject[26]).to eq variant.backorderable?
      expect(subject[27]).to eq variant.tax_category&.name
      expect(subject[28]).to eq variant.digital?
      expect(subject[29]).to end_with(variant.images[0].filename.to_s)
      expect(subject[30]).to end_with(variant.images[1].filename.to_s)
      expect(subject[31]).to end_with(variant.images[2].filename.to_s)
      expect(subject[32]).to eq nil
      expect(subject[33]).to eq nil
      expect(subject[34]).to eq nil
      expect(subject[35]).to eq nil
      expect(subject[36]).to eq nil
      expect(subject[37]).to eq nil
    end

    context 'when index is not zero' do
      let(:presenter) { described_class.new(product, variant, 1, properties, taxons, store, metafields) }

      let!(:color_option) { create(:option_type, name: 'Color', presentation: 'Color', products: [product]) }
      let!(:size_option) { create(:option_type, name: 'Size', presentation: 'Size', products: [product]) }

      let(:variant) { create(:variant, product: product, track_inventory: false, option_values: [red_color, small_size]) }

      let(:red_color) { create(:option_value, name: 'red', presentation: 'Red', option_type: color_option) }
      let(:small_size) { create(:option_value, name: 'small', presentation: 'Small', option_type: size_option) }

      it 'returns nil for product-level fields' do
        expect(subject[2]).to be_nil # name
        expect(subject[4]).to be_nil # status
        expect(subject[5]).to be_nil # vendor_name
      end

      it 'returns variant specific fields' do
        expect(subject[1]).to eq variant.sku
        expect(subject[13]).to eq variant.amount_in(store.default_currency).to_f
        expect(subject[24]).to eq false
        expect(subject[32]).to eq 'Color'
        expect(subject[33]).to eq 'Red'
        expect(subject[34]).to eq 'Size'
        expect(subject[35]).to eq 'Small'
        expect(subject[36]).to eq nil
        expect(subject[37]).to eq nil
      end
    end

    describe 'images host' do
      context 'when default host is set' do
        before do
          allow(Rails.application.routes).to receive(:default_url_options).and_return({ host: 'test.host' })
        end

        it 'returns images with default host' do
          expect(subject[29]).to start_with('http://test.host')
          expect(subject[30]).to start_with('http://test.host')
          expect(subject[31]).to start_with('http://test.host')
        end
      end

      context 'when there is no default host' do
        before do
          allow(Rails.application.routes).to receive(:default_url_options).and_return({})
        end

        it 'returns images with the store url' do
          expect(subject[29]).to start_with("http://#{store.url}")
          expect(subject[30]).to start_with("http://#{store.url}")
          expect(subject[31]).to start_with("http://#{store.url}")
        end

        context 'when custom domain is set' do
          let!(:custom_domain) { create(:custom_domain, store: store, url: 'custom.domain') }

          before { store.reload }

          it 'returns images with the custom domain' do
            expect(subject[29]).to start_with('http://custom.domain')
            expect(subject[30]).to start_with('http://custom.domain')
            expect(subject[31]).to start_with('http://custom.domain')
          end
        end
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

    it 'returns option value presentation for given option type' do
      expect(presenter.option_value(option_type)).to eq option_value.presentation
    end

    it 'returns nil for option type without value' do
      expect(presenter.option_value(create(:option_type))).to be_nil
    end
  end

  describe 'metafields' do
    context 'when index is zero' do
      let(:metafields) { ['value1', 'value2'] }
      let(:presenter) { described_class.new(product, variant, 0, properties, taxons, store, metafields) }

      it 'includes metafields at the end of the array' do
        result = presenter.call
        expect(result[-2]).to eq 'value1'
        expect(result[-1]).to eq 'value2'
      end
    end

    context 'when index is not zero' do
      let(:metafields) { ['value1', 'value2'] }
      let(:presenter) { described_class.new(product, variant, 1, properties, taxons, store, metafields) }

      it 'does not include metafields' do
        result = presenter.call
        expect(result).not_to include('value1')
        expect(result).not_to include('value2')
      end
    end
  end
end
