require 'spec_helper'

RSpec.describe Spree::Exports::NewsletterSubscribers, type: :model do
  let(:store) { @default_store }
  let(:export) { described_class.new(store: store) }

  describe '#csv_headers' do
    context 'when no custom_fields exist' do
      it 'returns newsletter subscriber headers' do
        expected_headers = [
          'Email',
          'Customer Name',
          'Customer ID',
          'Verified',
          'Verified At',
          'Created At',
          'Updated At'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end

    context 'when custom_fields exist' do
      let!(:custom_field_definition) do
        create(:custom_field_definition,
               resource_type: 'Spree::NewsletterSubscriber',
               namespace: 'custom',
               key: 'subscription_source')
      end

      it 'includes custom_field headers' do
        expected_headers = [
          'Email',
          'Customer Name',
          'Customer ID',
          'Verified',
          'Verified At',
          'Created At',
          'Updated At',
          'custom_field.custom.subscription_source'
        ]
        expect(export.csv_headers).to eq(expected_headers)
      end
    end
  end
end
