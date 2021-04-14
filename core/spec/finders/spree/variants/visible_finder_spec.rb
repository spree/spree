require 'spec_helper'

describe Spree::Variants::VisibleFinder do
  describe '#execute' do
    let(:currency) { 'USD' }

    let(:product) { create :product_with_option_types }
    let(:variant_1) { create :variant, product: product, option_values: [option_value_1] }
    let(:variant_2) { create :variant, product: product, option_values: [option_value_2] }
    let(:variant_3) { create :variant, product: product, option_values: [option_value_3] }

    let(:option_type) { product.option_types.first }

    let!(:option_value_1) { create :option_value, option_type: option_type, position: 2 }
    let!(:option_value_2) { create :option_value, option_type: option_type, position: 1 }
    let!(:option_value_3) { create :option_value, option_type: option_type, position: 1 }

    subject(:visible_variants) { described_class.new(scope: product.variants, current_currency: currency).execute }

    before do
      variant_3.prices.update_all(currency: 'PLN')
    end

    it 'returns variants ordered by option value position for passed currency' do
      expect(visible_variants).to eq([variant_2, variant_1])
    end
  end
end
