require 'spec_helper'

describe Spree::CanonicalNumber do
  describe '.parse' do
    it 'parses a plain decimal string regardless of the active locale' do
      allow(I18n).to receive(:locale).and_return(:de)
      allow(I18n.config).to receive(:locale).and_return(:de)

      expect(described_class.parse('24.99')).to eq(BigDecimal('24.99'))
    end

    it 'parses negative amounts' do
      expect(described_class.parse('-5.00')).to eq(BigDecimal('-5.00'))
    end

    it 'parses whole numbers without a decimal part' do
      expect(described_class.parse('100')).to eq(BigDecimal('100'))
    end

    it 'passes numeric values through untouched' do
      expect(described_class.parse(24.99)).to eq(BigDecimal('24.99'))
      expect(described_class.parse(BigDecimal('24.99'))).to eq(BigDecimal('24.99'))
    end

    it 'returns nil for nil and blank input' do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse('')).to be_nil
      expect(described_class.parse('  ')).to be_nil
    end

    it 'rejects a comma-decimal string instead of silently misparsing it' do
      expect { described_class.parse('24,99') }.to raise_error(Spree::CanonicalNumber::InvalidFormat)
    end

    it 'rejects a thousands-separated string instead of silently misparsing it' do
      expect { described_class.parse('1,599.99') }.to raise_error(Spree::CanonicalNumber::InvalidFormat)
    end

    it 'rejects non-numeric garbage' do
      expect { described_class.parse('abc') }.to raise_error(Spree::CanonicalNumber::InvalidFormat)
    end
  end
end
