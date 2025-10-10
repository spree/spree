require 'spec_helper'

describe Spree::Variants::OptionTypesPresenter do
  let(:option_type_1) { create :option_type, position: 2 }
  let(:option_type_2) { create :option_type, position: 1 }

  let(:product) { create :product, option_types: [option_type_1, option_type_2] }
  let(:product_2) { create :product, option_types: [option_type_1, option_type_2] }

  let!(:variant_0) { create :variant, product: product, option_values: [option_value_1_0, option_value_2_0] }
  let!(:variant_1) { create :variant, product: product, option_values: [option_value_1_1, option_value_2_2] }
  let!(:variant_2) { create :variant, product: product, option_values: [option_value_1_2, option_value_2_1] }
  let!(:variant_3) { create :variant, product: product_2, option_values: [option_value_1_2, option_value_2_1] }

  let(:variants) { product.reload.variants }

  let!(:option_value_1_0) { create :option_value, option_type: option_type_1, position: 0 }
  let!(:option_value_1_1) { create :option_value, option_type: option_type_1, position: 2 }
  let!(:option_value_1_2) { create :option_value, option_type: option_type_1, position: 1 }
  let!(:option_value_2_0) { create :option_value, option_type: option_type_2, position: 0 }
  let!(:option_value_2_1) { create :option_value, option_type: option_type_2, position: 2 }
  let!(:option_value_2_2) { create :option_value, option_type: option_type_2, position: 1 }

  let(:option_types) do
    Spree::OptionType.
      eager_load(:option_values).
      reorder('spree_option_types.position ASC, spree_option_values.position ASC')
  end

  describe '#default_variant' do
    subject(:default_variant) { described_class.new(option_types, variants, product).default_variant }

    before { variant_0.stock_items.first.update(backorderable: false, count_on_hand: 0) }

    context 'default variant of product' do
      context 'backorderable' do
        before { variant_0.stock_items.first.update(backorderable: true) }

        it 'returns the same Variant as Product#default_variant' do
          expect(default_variant).to eq(variant_0)
          expect(product.default_variant).to eq(variant_0)
        end
      end

      context 'in stock' do
        before { variant_0.stock_items.first.adjust_count_on_hand(1) }

        it 'returns the same Variant as Product#default_variant' do
          expect(default_variant).to eq(variant_0)
          expect(product.default_variant).to eq(variant_0)
        end
      end
    end

    it 'returns first Variant of first Option Value of first Option Type' do
      expect(default_variant).to eq(variant_1)
    end

    context 'with in-stock Variant' do
      before do
        variant_0.stock_items.first.update(backorderable: false, count_on_hand: 0)
        variant_1.stock_items.first.update(backorderable: false, count_on_hand: 0)
        variant_2.stock_items.first.adjust_count_on_hand(1)
      end

      it 'returns first in-stock Variant' do
        expect(default_variant).to eq(variant_2)
      end
    end

    context 'with backorderable Variant' do
      before do
        variant_1.stock_items.first.update!(backorderable: false)
        variant_2.stock_items.first.update!(backorderable: true)
      end

      it 'returns first backorderable Variant' do
        expect(default_variant).to eq(variant_2)
      end
    end

    context 'without Option Types' do
      let(:option_types) { [] }

      it { is_expected.to eq(nil) }
    end
  end

  describe '#options' do
    subject(:options) { described_class.new(option_types, variants, product).options }

    it 'returns serialized options for Option Types and Option Values' do
      expect(options).to eq(
        [
          {
            id: option_type_2.reload.id,
            name: option_type_2.name,
            position: option_type_2.position,
            presentation: option_type_2.presentation,
            option_values: [
              {
                id: option_value_2_2.reload.id,
                is_default: false,
                position: option_value_2_2.position,
                presentation: option_value_2_2.presentation,
                name: option_value_2_2.name,
                variant_id: variant_1.id
              },
              {
                id: option_value_2_1.reload.id,
                is_default: false,
                position: option_value_2_1.position,
                presentation: option_value_2_1.presentation,
                name: option_value_2_1.name,
                variant_id: variant_2.id
              },
              {
                id: option_value_2_0.reload.id,
                is_default: true,
                position: option_value_2_0.position,
                presentation: option_value_2_0.presentation,
                name: option_value_2_0.name,
                variant_id: variant_0.id
              }
            ]
          },
          {
            id: option_type_1.reload.id,
            name: option_type_1.name,
            position: option_type_1.position,
            presentation: option_type_1.presentation,
            option_values: [
              {
                id: option_value_1_2.reload.id,
                is_default: false,
                position: option_value_1_2.position,
                presentation: option_value_1_2.presentation,
                name: option_value_1_2.name,
                variant_id: variant_2.id
              },
              {
                id: option_value_1_0.reload.id,
                is_default: false,
                position: option_value_1_0.position,
                presentation: option_value_1_0.presentation,
                name: option_value_1_0.name,
                variant_id: variant_0.id
              },
              {
                id: option_value_1_1.reload.id,
                is_default: false,
                position: option_value_1_1.position,
                presentation: option_value_1_1.presentation,
                name: option_value_1_1.name,
                variant_id: variant_1.id
              }
            ]
          }
        ]
      )
    end

    context 'without Option Types' do
      let(:option_types) { [] }

      it { is_expected.to eq([]) }
    end
  end
end
