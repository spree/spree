# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::BaseSerializer do
  let(:test_class) do
    Class.new(described_class) do
      protected

      def attributes
        {
          id: resource.id,
          name: resource.name,
          created_at: timestamp(resource.created_at)
        }
      end
    end
  end

  let(:resource) { Spree::Product.new(id: 1, name: 'Test Product', created_at: Time.zone.parse('2024-01-15 10:30:00')) }
  let(:context) { { event_name: 'product.test' } }
  let(:serializer) { test_class.new(resource, context) }

  describe '#as_json' do
    subject { serializer.as_json }

    it 'returns a hash with attributes' do
      expect(subject).to be_a(Hash)
      expect(subject[:id]).to eq(1)
      expect(subject[:name]).to eq('Test Product')
    end

    it 'formats timestamps as ISO8601' do
      expect(subject[:created_at]).to eq('2024-01-15T10:30:00Z')
    end
  end

  describe '.serialize' do
    it 'creates an instance and calls as_json' do
      result = test_class.serialize(resource, context)
      expect(result).to be_a(Hash)
      expect(result[:id]).to eq(1)
    end
  end

  describe '#timestamp' do
    it 'returns nil for nil values' do
      expect(serializer.send(:timestamp, nil)).to be_nil
    end

    it 'returns ISO8601 formatted string' do
      time = Time.zone.parse('2024-06-15 14:30:00')
      expect(serializer.send(:timestamp, time)).to eq('2024-06-15T14:30:00Z')
    end
  end

  describe '#money' do
    it 'returns nil for nil values' do
      expect(serializer.send(:money, nil)).to be_nil
    end

    it 'returns decimal value for numbers' do
      expect(serializer.send(:money, 10.50)).to eq(10.50)
    end

    it 'returns decimal value for BigDecimal' do
      expect(serializer.send(:money, BigDecimal('99.99'))).to eq(BigDecimal('99.99'))
    end
  end

  describe '#event_name' do
    it 'returns the event name from context' do
      expect(serializer.send(:event_name)).to eq('product.test')
    end
  end

  describe '#attribute' do
    it 'returns the attribute value if it exists' do
      expect(serializer.send(:attribute, :name)).to eq('Test Product')
    end

    it 'returns nil if the attribute does not exist' do
      expect(serializer.send(:attribute, :nonexistent)).to be_nil
    end
  end
end
