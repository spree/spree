require 'spec_helper'

RSpec.describe Spree::Measurement do
  describe '.to_centimeters' do
    it 'converts every supported length unit' do
      expect(described_class.to_centimeters(1, unit: 'cm')).to eq(BigDecimal('1'))
      expect(described_class.to_centimeters(10, unit: 'mm')).to eq(BigDecimal('1'))
      expect(described_class.to_centimeters(1, unit: 'in')).to eq(BigDecimal('2.54'))
      expect(described_class.to_centimeters(1, unit: 'ft')).to eq(BigDecimal('30.48'))
    end

    it 'reads a blank or unrecognized unit as centimeters' do
      expect(described_class.to_centimeters(5, unit: nil)).to eq(BigDecimal('5'))
      expect(described_class.to_centimeters(5, unit: 'furlongs')).to eq(BigDecimal('5'))
    end

    it 'is case insensitive' do
      expect(described_class.to_centimeters(1, unit: 'IN')).to eq(BigDecimal('2.54'))
    end

    it 'answers nil for a missing value rather than zero' do
      expect(described_class.to_centimeters(nil, unit: 'cm')).to be_nil
      expect(described_class.to_centimeters('', unit: 'cm')).to be_nil
    end
  end

  describe '.to_kilograms' do
    it 'converts every supported weight unit' do
      expect(described_class.to_kilograms(1, unit: 'kg')).to eq(BigDecimal('1'))
      expect(described_class.to_kilograms(1000, unit: 'g')).to eq(BigDecimal('1'))
      expect(described_class.to_kilograms(1, unit: 'lb')).to eq(BigDecimal('0.45359237'))
      expect(described_class.to_kilograms(16, unit: 'oz')).to eq(BigDecimal('0.45359237'))
    end

    it 'answers nil for a missing value' do
      expect(described_class.to_kilograms(nil)).to be_nil
    end
  end

  describe '.convert_length' do
    it 'converts between any two supported units' do
      expect(described_class.convert_length(2.54, from: 'cm', to: 'in')).to eq(BigDecimal('1'))
      expect(described_class.convert_length(1, from: 'ft', to: 'in')).to eq(BigDecimal('12'))
      expect(described_class.convert_length(1, from: 'cm', to: 'mm')).to eq(BigDecimal('10'))
    end

    it 'is the identity when the units match' do
      expect(described_class.convert_length(7, from: 'in', to: 'in')).to eq(BigDecimal('7'))
    end

    it 'answers nil for a missing value' do
      expect(described_class.convert_length(nil, from: 'cm', to: 'in')).to be_nil
    end
  end

  describe '.convert_weight' do
    it 'converts between any two supported units' do
      expect(described_class.convert_weight(1, from: 'kg', to: 'g')).to eq(BigDecimal('1000'))
      expect(described_class.convert_weight(1, from: 'lb', to: 'oz')).to eq(BigDecimal('16'))
    end

    it 'is the identity when the units match' do
      expect(described_class.convert_weight(3, from: 'lb', to: 'lb')).to eq(BigDecimal('3'))
    end
  end

  describe '.cubic_meters' do
    it 'converts a metric box' do
      expect(described_class.cubic_meters(100, 100, 100, unit: 'cm')).to eq(BigDecimal('1'))
    end

    # The whole reason the helper exists: the same three numbers mean very
    # different volumes depending on the unit, so freight math can never
    # multiply raw dimension columns.
    it 'reads the same numbers in inches as roughly sixteen times the volume' do
      metric = described_class.cubic_meters(10, 10, 10, unit: 'cm')
      imperial = described_class.cubic_meters(10, 10, 10, unit: 'in')

      expect(imperial / metric).to be_within(0.01).of(16.387)
    end

    it 'answers nil when a dimension is missing or zero' do
      expect(described_class.cubic_meters(10, 10, nil, unit: 'cm')).to be_nil
      expect(described_class.cubic_meters(10, 0, 10, unit: 'cm')).to be_nil
      expect(described_class.cubic_meters(nil, nil, nil, unit: 'cm')).to be_nil
    end
  end
end
