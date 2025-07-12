require 'spec_helper'

module Spree
  describe ImportService::Products::Update, import: true do
    subject(:service) { described_class.new(row: row) }

    let(:row) do
      {
        name: 'Sample',
        description: 'Sample product from ASD',
        available_on: '2010.05.20 21:00 +1'.to_datetime.to_s,
        meta_description: 'not a premium',
        meta_keywords: '365',
        price: '10.00',
        cost_price: '10.00',
        sku: sku,
        weight: '20',
        height: '30',
        width: '40',
        depth: '50',
        shipping_category: create(:shipping_category).name,
        tax_category: create(:tax_category).name,
        # taxons (optional if time permits)
        option1_name: create(:option_type).name,
        option1_value: create(:option_value).name,
        option2_name: create(:option_type).name,
        option2_value: create(:option_value).name,
        property1_name: create(:property).name,
        property1_value: 'bebe',
        property2_name: create(:property).name,
        property2_value: 'qwer'
      }
    end

    let(:create_klass) { ImportService::Products::Create }
    let(:create_instance) { double(call: nil) }

    let(:update_klass) { ImportService::Products::Update }
    let(:update_instance) { double(call: nil) }

    let(:variant) { create(:variant) }
    let(:sku) { variant.sku }
    let(:product) { variant.product }
      
    context 'with valid params' do
      let(:expected_variant_attributes) do
        {
          weight: 20,
          height: 30,
          cost_price: 10.00
        }.stringify_keys
      end

      let(:expected_product_attributes) do
        {
          name: 'Sample',
          description: 'Sample product from ASD',
          available_on: '2010.05.20 21:00 +1'.to_datetime,
          meta_description: 'not a premium',
          meta_keywords: '365',
          tax_category_id: kind_of(Integer),
          shipping_category_id: kind_of(Integer)
        }.stringify_keys
      end

      it 'updates variant' do
        expect { service.call }.to change { variant.reload.attributes }.to(a_hash_including(expected_variant_attributes))
      end

      it 'updates product' do
        expect { service.call }.to change { product.reload.attributes }.to(a_hash_including(expected_product_attributes))
      end

      it 'updates option types' do
        expect { service.call }.to change { product.reload.option_types }.and(change { variant.reload.option_values })
      end

      it 'updates properties' do
        expect { service.call }.to change { product.reload.properties }
      end
    end
  end
end
