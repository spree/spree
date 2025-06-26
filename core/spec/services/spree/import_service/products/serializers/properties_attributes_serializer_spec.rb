require 'spec_helper'

module Spree
  describe ImportService::Products::Serializers::PropertiesAttributesSerializer do
    subject(:serializer) { described_class.new(row: row, product_id: product_id) }

    let(:row) do
      {
        name: 'Sample',
        description: 'Sample product from ASD',
        available_on: '2010.05.20 21:00 +1'.to_datetime.to_s,
        meta_description: { premium: false },
        meta_keywords: ['365', 'affortable'],
        price: '10.00',
        cost_price: '',
        sku: 'ALA-MA-KOTA',
        weight: '20',
        height: '30',
        width: '40',
        depth: '50',
        shipping_category: 'default',
        tax_category: 'default',
        # taxons (optional if time permits)
        option1_name: 'option1',
        option1_value: 'option2',
        option2_name: 'option2',
        option2_value: 'value2',
        property1_name: chosen_property1_name,
        property1_value: 'bebe',
        property2_name: chosen_property2_name,
        property2_value: 'qwer'
      }.stringify_keys
    end

    let(:chosen_property1_name) { property1.name }
    let(:chosen_property2_name) { property2.name }
    
    let(:property1) { create(:property) }
    let(:property2) { create(:property) }

    let(:product_id) { 123 }

    describe '#to_a' do
      subject(:to_a) { serializer.to_a }

      context 'with valid data' do
        let(:expected_result) do
          [
            {
              property_id: property1.id,
              position: 0,
              value: row['property1_value'],
              product_id: product_id
            },
            {
              property_id: property2.id,
              position: 1,
              value: row['property2_value'],
              product_id: product_id
            }
          ]
        end

        it 'returns serialized option types with valid order and values' do
          expect(to_a).to match_array(expected_result)
        end
      end

      context 'with non-existing property' do
        let(:chosen_property1_name) { 'im-not-here' }

        it 'raises ImportService::Error' do
          expect { to_a }.to raise_error(KeyError)
        end
      end
    end
  end
end