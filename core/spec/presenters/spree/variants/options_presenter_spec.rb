require 'spec_helper'

describe Spree::Variants::OptionsPresenter do
  describe '#to_sentence' do
    let(:option_type_1) { create :option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type' }
    let(:option_type_2) { create :option_type, position: 1, name: 'Bar Type', presentation: 'Bar Type' }

    let(:option_value_1) { create :option_value, name: 'Foo', presentation: 'Foo', option_type: option_type_1 }
    let(:option_value_2) { create :option_value, name: 'Bar', presentation: 'Bar', option_type: option_type_2 }

    let(:variant) { build :variant, option_values: [option_value_1, option_value_2] }

    subject(:to_sentence) { described_class.new(variant).to_sentence }

    # Regression test for #2432
    it 'orders by bar than foo' do
      expect(to_sentence).to eq 'Bar Type: Bar, Foo Type: Foo'
    end
  end

  describe '#to_hash' do
    subject { described_class.new(variant).to_hash }

    let(:option_type_1) { create :option_type, name: 'color', presentation: 'Color' }
    let(:option_value_1) { create :option_value, option_type: option_type_1, name: 'white', presentation: 'White' }
    let(:option_type_2) { create :option_type, name: 'size', presentation: 'Size' }
    let(:option_value_2) { create :option_value, option_type: option_type_2, name: 'Medium', presentation: 'Medium' }

    context 'when variant has option values' do
      let(:variant) { create :variant, option_values: [option_value_1, option_value_2] }

      it 'returns valid hash' do
        expect(subject).to eq({ color: 'White', size: 'Medium' })
      end
    end

    context 'when variant has no option values' do
      let(:product) { create(:product) }
      let(:variant) { product.master }

      it 'returns empty hash' do
        expect(subject).to eq({})
      end
    end
  end
end
