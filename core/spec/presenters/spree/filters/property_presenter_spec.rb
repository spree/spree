require 'spec_helper'

module Spree
  RSpec.describe Filters::PropertyPresenter do
    let(:property) { described_class.new(property: brand, product_properties: product_properties) }
    let(:product_properties) { [alpha_brand, beta_brand] }

    let(:brand) { create(:property, :brand, :filterable) }
    let(:alpha_brand) { create(:product_property, property: brand, value: 'Alpha') }
    let(:beta_brand) { create(:product_property, property: brand, value: 'Beta') }

    before do
      create(:product_property, property: brand, value: 'Gamma')
    end

    describe '#uniq_values' do
      subject(:uniq_values) { property.uniq_values }

      it 'returns unique Product Properties values for a given list of Product Properties' do
        expect(uniq_values).to eq([['alpha', 'Alpha'], ['beta', 'Beta']])
      end
    end
  end
end
