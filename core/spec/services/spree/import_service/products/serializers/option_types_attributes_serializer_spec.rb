require 'spec_helper'

module Spree
  describe ImportService::Products::Serializers::OptionTypesAttributesSerializer, import: true do
    subject(:serializer) { described_class.new(row: row, product_id: product_id) }

    let(:row) do
      {
        name: 'Sample',
        description: 'Sample product from ASD',
        available_on: '2010.05.20 21:00 +1'.to_datetime.to_s,
        meta_description: { premium: false },
        meta_keywords: ['356', 'affortable'],
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
        option1_name: chosen_option1_name,
        option1_value: chosen_option1_value,
        option2_name: chosen_option2_name,
        option2_value: chosen_option2_value,
        property1_name: 'property2',
        property1_value: 'property2',
        extra_param: 'extra'
      }.stringify_keys
    end

    let(:chosen_option1_name) { option1_type.name }
    let(:chosen_option1_value) { option1_value.name }
    let(:chosen_option2_name) { option2_type.name }
    let(:chosen_option2_value) { option2_value.name }
    
    let(:option1_type) { create(:option_type) }
    let(:option1_value) { create(:option_value) }
    let(:option2_type) { create(:option_type) }
    let(:option2_value) { create(:option_value) }

    let(:product_id) { 123 }
    
    before do
      create(:option_type)
    end

    describe '#to_a' do
      subject(:to_a) { serializer.to_a }

      context 'with valid data' do
        let(:expected_result) do
          [
            {
              option_type_id: option1_type.id,
              position: 0,
              product_id: product_id
            },
            {
              option_type_id: option2_type.id,
              position: 1,
              product_id: product_id
            }
          ]
        end

        it 'returns serialized option types with valid order' do
          expect(to_a).to match_array(expected_result)
        end
      end

      context 'with non-existing option type' do
        let(:chosen_option1_name) { 'qwerty' }
        
        it 'raises ImportService::Error' do
          expect { to_a }.to raise_error(Spree::ImportService::Error)
        end
      end
    end
  end
end