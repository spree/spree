require 'spec_helper'

module Spree
  describe ImportService::Products::Create, import: true do
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
        sku: 'totally-new-sku',
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

      it 'creates variant and product', aggregate_failure: true do
        expect { service.call }.to change(Spree::Variant, :count).by(2)
          .and(change(Spree::Product, :count).by(1))
          .and(change(Spree::ProductOptionType, :count).by(2))
          .and(change(Spree::OptionValueVariant, :count).by(2))
          .and(change(Spree::ProductProperty, :count).by(2))
      end

      it 'assigns valid attributes to new resources' do
        service.call

        variant = Spree::Variant.find_by(sku: row[:sku])

        expect(variant.attributes).to match(a_hash_including(expected_variant_attributes))
        expect(variant.product.attributes).to match(a_hash_including(expected_product_attributes))
      end
    end
  end
end
