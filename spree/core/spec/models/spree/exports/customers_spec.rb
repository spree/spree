require 'spec_helper'

RSpec.describe Spree::Exports::Customers, type: :model do
  let(:store) { @default_store }
  let(:export) { described_class.new(store: store) }

  describe '#csv_headers' do
    context 'when no custom_fields exist' do
      it 'returns customer headers' do
        expected_headers = [
          'First Name',
          'Last Name',
          'Email',
          'Accepts Email Marketing',
          'Company',
          'Address 1',
          'Address 2',
          'City',
          'Province',
          'Province Code',
          'Country',
          'Country Code',
          'Zip',
          'Phone',
          'Total Spent',
          'Total Orders',
          'Tags'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end

    context 'when custom_fields exist' do
      let!(:custom_field_definition) do
        create(:custom_field_definition,
               resource_type: export.model_class.to_s,
               namespace: 'custom',
               key: 'loyalty_points')
      end

      it 'includes custom_field headers' do
        expected_headers = [
          'First Name',
          'Last Name',
          'Email',
          'Accepts Email Marketing',
          'Company',
          'Address 1',
          'Address 2',
          'City',
          'Province',
          'Province Code',
          'Country',
          'Country Code',
          'Zip',
          'Phone',
          'Total Spent',
          'Total Orders',
          'Tags',
          'custom_field.custom.loyalty_points'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end
  end
end
