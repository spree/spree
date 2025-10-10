require 'spec_helper'

module Spree
  RSpec.describe Filters::PropertiesPresenter do
    let(:properties) { described_class.new(product_properties_scope: ProductProperty.where(id: product_properties)) }
    let(:product_properties) { [alpha_brand, beta_brand, wilson_manufacturer] }

    let(:brand) { create(:property, :brand, :filterable) }
    let(:alpha_brand) { create(:product_property, property: brand, value: 'Alpha') }
    let(:beta_brand) { create(:product_property, property: brand, value: 'Beta') }

    let(:manufacturer) { create(:property, :manufacturer, :filterable) }
    let(:wilson_manufacturer) { create(:product_property, property: manufacturer, value: 'Wilson') }

    before do
      create(:product_property, property: brand, value: 'Gamma')
      create(:product_property, property: manufacturer, value: 'Jerseys')
    end

    describe '#to_a' do
      subject(:filterable_properties) { properties.to_a }

      it 'returns filterable Product Properties' do
        aggregate_failures 'filterable product properties' do
          brand_property = filterable_properties.find { |property| property.name == brand.name }
          expect(brand_property.product_properties).to contain_exactly(alpha_brand, beta_brand)

          manufacturer_property = filterable_properties.find { |property| property.name == manufacturer.name }
          expect(manufacturer_property.product_properties).to contain_exactly(wilson_manufacturer)
        end
      end
    end
  end
end
