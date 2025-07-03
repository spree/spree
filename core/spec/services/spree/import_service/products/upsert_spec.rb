require 'spec_helper'

module Spree
  describe ImportService::Products::Upsert do
    subject(:service) { described_class.new(row: row) }

    let(:row) do
      {
        name: 'Sample',
        description: 'Sample product from ASD',
        available_on: '2010.05.20 21:00 +1'.to_datetime.to_s,
        meta_description: { premium: false },
        meta_keywords: ['365', 'affortable'],
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
        option1_value: 'option2',
        option2_name: create(:option_type).name,
        option2_value: 'value2',
        property1_name: create(:property).name,
        property1_value: 'bebe',
        property2_name: create(:property).name,
        property2_value: 'qwer'
      }.stringify_keys
    end

    let(:create_klass) { ImportService::Products::Create }
    let(:create_instance) { double(call: nil) }

    let(:update_klass) { ImportService::Products::Update }
    let(:update_instance) { double(call: nil) }

    before do
      allow(create_klass).to receive(:new).with(row: row).and_return(create_instance)
      allow(update_klass).to receive(:new).with(row: row).and_return(update_instance)
    end

    context 'with existing SKU' do
      let(:sku) { create(:variant).sku }
      
      it 'calls Update service' do
        expect(update_instance).to receive(:call).once

        service.call
      end

      it 'does not call Create service' do
        expect(create_instance).to_not receive(:call)

        service.call
      end
    end

    context 'with non-existing SKU' do
      let(:sku) { 'ALA-MA-KOTA' }

      it 'calls Create service' do
        expect(create_instance).to receive(:call).once

        service.call
      end

      it 'does not call Update service' do
        expect(update_instance).to_not receive(:call)

        service.call
      end
    end
  end
end
