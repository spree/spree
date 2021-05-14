require 'spec_helper'

module Spree
  RSpec.describe ProductProperties::FindAvailable do
    let(:finder) { described_class.new }

    let(:brand) { create(:property, :brand, :filterable) }
    let(:alpha_brand) { create(:product_property, property: brand, value: 'Alpha') }
    let(:beta_brand) { create(:product_property, property: brand, value: 'Beta') }
    let(:gamma_brand) { create(:product_property, property: brand, value: 'Gamma') }

    let(:manufacturer) { create(:property, :manufacturer, :filterable) }
    let(:wilson_manufacturer) { create(:product_property, property: manufacturer, value: 'Wilson') }
    let(:jerseys_manufacturer) { create(:product_property, property: manufacturer, value: 'Jerseys') }

    describe '#execute' do
      subject(:available_properties) { finder.execute }

      it 'finds available Product Properties' do
        expect(available_properties).to contain_exactly(
          alpha_brand, beta_brand, gamma_brand,
          wilson_manufacturer, jerseys_manufacturer
        )
      end

      context 'when given a predefined scope' do
        let(:finder) { described_class.new(scope: scope) }
        let(:scope) { ProductProperty.where(id: [beta_brand, jerseys_manufacturer]) }

        it 'finds available Product Properties with respect to a predefined scope' do
          expect(available_properties).to contain_exactly(beta_brand, jerseys_manufacturer)
        end
      end

      context 'when given a predefined products scope' do
        let(:finder) { described_class.new(products_scope: products_scope) }
        let(:products_scope) { Product.where(id: [product_1, product_2, product_3]) }

        let(:product_1) { alpha_brand.product }
        let(:product_2) { gamma_brand.product }
        let(:product_3) { wilson_manufacturer.product }

        it 'finds filterable Product Properties with respect to a predefined Products scope' do
          expect(available_properties).to contain_exactly(
            alpha_brand, gamma_brand,
            wilson_manufacturer
          )
        end
      end
    end
  end
end
