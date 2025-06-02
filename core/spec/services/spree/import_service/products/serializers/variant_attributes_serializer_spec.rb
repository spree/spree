require 'spec_helper'

module Spree
  describe ImportService::Products::Serializers::VariantAttributesSerializer do
    subject(:serializer) { described_class.new(row: row) }

    let(:row) do
      {
        name: 'Sample',
        description: 'Sample product from ASD',
        available_on: '2010.05.20 21:00 +1'.to_datetime.to_s,
        meta_description: { premium: false },
        meta_keywords: ['365', 'affortable'],
        price: '10.20',
        cost_price: cost_price,
        sku: 'ALA-MA-KOTA',
        weight: '20',
        height: '',
        width: '40',
        depth: '50',
        shipping_category: 'name1',
        tax_category: 'name2',
        # taxons (optional if time permits)
        option1_name: 'option1',
        option1_value: 'option2',
        option2_name: 'option2',
        option2_value: 'value2',
        property1_name: 'color_outside',
        property1_value: 'bebe',
        property2_name: 'color_inside',
        property2_value: 'qwer'
      }.stringify_keys
    end

    let(:cost_price) { '10.20' }

    describe '#to_h' do
      subject(:to_h) { serializer.to_h }

      context 'with valid data' do
        let(:expected_result) do
          {
            cost_price: 10.20,
            sku: "ALA-MA-KOTA",
            weight: 20,
            height: nil,
            width: 40,
            depth: 50
          }
        end

        it 'returns serialized option types with valid order and values' do
          expect(to_h).to include(expected_result)
        end
      end

      context 'with invalid data' do
        context 'with invalid numeric value' do
          let(:cost_price) { 'no a number' }

          it 'raises an error' do
            expect { to_h }.not_to raise_error
          end
        end
      end
    end
  end
end