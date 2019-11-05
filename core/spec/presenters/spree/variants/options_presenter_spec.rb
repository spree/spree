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

    context 'when OptionType is color' do
      let(:option_type) { create :option_type, name: 'color', presentation: 'Color' }
      let(:option_value) { create :option_value, option_type: option_type, name: 'white', presentation: '#FFFFFF' }

      let(:variant) { build :variant, option_values: [option_value] }

      it 'uses name of OptionValue instead of presentation' do
        expect(to_sentence).to eq 'Color: white'
      end
    end
  end
end
