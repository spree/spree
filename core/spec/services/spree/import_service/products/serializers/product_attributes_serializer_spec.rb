require 'spec_helper'

module Spree
  describe ImportService::Products::Serializers::ProductAttributesSerializer, import: true do
    subject(:serializer) { described_class.new(row: row) }

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
        shipping_category: chosen_shipping_category_name,
        tax_category: chosen_tax_category_name,
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

    let(:available_on) { '2010.05.20 21:00 +1'.to_datetime }

    let(:chosen_shipping_category_name) { shipping_category.name }
    let(:chosen_tax_category_name) { tax_category.name }

    let(:shipping_category) { create(:shipping_category) }
    let(:tax_category) { create(:tax_category) }

    describe '#to_h' do
      subject(:to_h) { serializer.to_h }

      context 'with valid data' do
        let(:expected_result) do
          {
            name: 'Sample',
            description: 'Sample product from ASD',
            available_on: available_on,
            meta_description: { premium: false },
            meta_keywords: ['365', 'affortable'],
            tax_category_id: tax_category.id,
            shipping_category_id: shipping_category.id
          }
        end

        it 'returns serialized option types with valid order and values' do
          expect(to_h).to include(expected_result)
        end
      end

      context 'with non-existing shipping category' do
        let(:chosen_shipping_category_name) { 'im-not-here' }

        it 'raises ImportService::Error' do
          expect { to_h }.to raise_error(Spree::ImportService::Error)
        end
      end

      context 'with non-existing tax category' do
        let(:chosen_tax_category_name) { 'im-not-here' }

        it 'raises ImportService::Error' do
          expect { to_h }.to raise_error(Spree::ImportService::Error)
        end
      end
    end
  end
end