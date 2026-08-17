require 'spec_helper'

RSpec.describe Spree::Exports::Orders, type: :model do
  let(:store) { @default_store }
  let(:export) { described_class.new(store: store) }

  describe '#csv_headers' do
    context 'when no custom_fields exist' do
      it 'returns order line item headers' do
        expected_headers = [
          'Number',
          'Email',
          'Status',
          'Currency',
          'Subtotal',
          'Shipping',
          'Taxes',
          'Taxes included',
          'Discount Used',
          'Free Shipping',
          'Discount',
          'Discount Code',
          'Store Credit amount',
          'Total',
          'Shipping method',
          'Total weight',
          'Payment Type Used',
          'Product ID',
          'Item Quantity',
          'Item SKU',
          'Item Name',
          'Item Price',
          'Item Total Discount',
          'Item Total Price',
          'Item requires shipping',
          'Item taxbale',
          'Item Seller',
          'Category lvl0',
          'Category lvl1',
          'Category lvl2',
          'Category lvl3',
          'Category lvl4',
          'Billing Name',
          'Billing Address 1',
          'Billing Address 2',
          'Billing Company',
          'Billing City',
          'Billing Zip',
          'Billing State',
          'Billing Country',
          'Billing Phone',
          'Shipping Name',
          'Shipping Address 1',
          'Shipping Address 2',
          'Shipping Company',
          'Shipping City',
          'Shipping Zip',
          'Shipping State',
          'Shipping Country',
          'Shipping Phone',
          'Placed at',
          'Shipped at',
          'Cancelled at',
          'Cancelled by',
          'Notes'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end

    context 'when custom_fields exist' do
      let!(:custom_field_definition) do
        create(:custom_field_definition,
               resource_type: 'Spree::Order',
               namespace: 'custom',
               key: 'gift_message')
      end

      it 'includes custom_field headers' do
        expected_headers = [
          'Number',
          'Email',
          'Status',
          'Currency',
          'Subtotal',
          'Shipping',
          'Taxes',
          'Taxes included',
          'Discount Used',
          'Free Shipping',
          'Discount',
          'Discount Code',
          'Store Credit amount',
          'Total',
          'Shipping method',
          'Total weight',
          'Payment Type Used',
          'Product ID',
          'Item Quantity',
          'Item SKU',
          'Item Name',
          'Item Price',
          'Item Total Discount',
          'Item Total Price',
          'Item requires shipping',
          'Item taxbale',
          'Item Seller',
          'Category lvl0',
          'Category lvl1',
          'Category lvl2',
          'Category lvl3',
          'Category lvl4',
          'Billing Name',
          'Billing Address 1',
          'Billing Address 2',
          'Billing Company',
          'Billing City',
          'Billing Zip',
          'Billing State',
          'Billing Country',
          'Billing Phone',
          'Shipping Name',
          'Shipping Address 1',
          'Shipping Address 2',
          'Shipping Company',
          'Shipping City',
          'Shipping Zip',
          'Shipping State',
          'Shipping Country',
          'Shipping Phone',
          'Placed at',
          'Shipped at',
          'Cancelled at',
          'Cancelled by',
          'Notes',
          'custom_field.custom.gift_message'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end
  end

  describe '#multi_line_csv?' do
    it 'returns true' do
      expect(export.multi_line_csv?).to be true
    end
  end
end
