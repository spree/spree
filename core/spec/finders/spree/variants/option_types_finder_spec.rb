require 'spec_helper'

describe Spree::Variants::OptionTypesFinder do
  describe '#execute' do
    let(:option_type_1) { create :option_type, position: 2 }
    let(:option_type_2) { create :option_type, position: 1 }

    let(:product) { create :product, option_types: [option_type_1, option_type_2] }

    let!(:variant_1) { create :variant, product: product, option_values: [option_value_1_1, option_value_2_2] }
    let!(:variant_2) { create :variant, product: product, option_values: [option_value_1_2, option_value_2_1] }

    let!(:option_value_1_1) { create :option_value, option_type: option_type_1, position: 2 }
    let!(:option_value_1_2) { create :option_value, option_type: option_type_1, position: 1 }
    let!(:option_value_2_1) { create :option_value, option_type: option_type_2, position: 2 }
    let!(:option_value_2_2) { create :option_value, option_type: option_type_2, position: 1 }

    let!(:another_option_type) { create :option_type }
    let!(:another_product) { create :product, option_types: [another_option_type] }
    let!(:another_variant) { create :variant, product: product, option_values: [another_option_value] }
    let!(:another_option_value) { create :option_value, option_type: another_option_type }

    subject(:option_types) { described_class.new(variant_ids: [variant_1.id, variant_2.id]).execute }

    it "returns ordered Option Types and Option Values" do
      expect(option_types).to eq([option_type_2, option_type_1])

      expect(option_types.first.option_values).to eq([option_value_2_2, option_value_2_1])
      expect(option_types.second.option_values).to eq([option_value_1_2, option_value_1_1])
    end

    context "when Option Type is color" do
      let(:option_type_1) { create :option_type, position: 2, name: 'color' }

      it "returns color Option Type first" do
        expect(option_types).to eq([option_type_1, option_type_2])
      end
    end
  end
end
