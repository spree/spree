require 'spec_helper'

RSpec.describe Spree::CSV::FormulaSanitizer do
  describe '.cell' do
    %w[= + - @].each do |trigger|
      it "prefixes strings beginning with #{trigger.inspect}" do
        expect(described_class.cell("#{trigger}cmd|'/C calc'!A1")).to eq("'#{trigger}cmd|'/C calc'!A1")
      end
    end

    it 'prefixes strings beginning with a tab' do
      expect(described_class.cell("\t=2+2")).to eq("'\t=2+2")
    end

    it 'prefixes strings beginning with a carriage return' do
      expect(described_class.cell("\r=2+2")).to eq("'\r=2+2")
    end

    it 'prefixes strings beginning with a line feed' do
      expect(described_class.cell("\n=2+2")).to eq("'\n=2+2")
    end

    it 'leaves plain strings untouched' do
      expect(described_class.cell('Alice')).to eq('Alice')
      expect(described_class.cell('alice@example.com')).to eq('alice@example.com')
      expect(described_class.cell('123 Main St')).to eq('123 Main St')
    end

    it 'leaves empty strings untouched' do
      expect(described_class.cell('')).to eq('')
    end

    it 'leaves non-string values untouched' do
      expect(described_class.cell(nil)).to be_nil
      expect(described_class.cell(42)).to eq(42)
      expect(described_class.cell(3.14)).to eq(3.14)
      expect(described_class.cell(true)).to be(true)
      expect(described_class.cell(Date.new(2026, 1, 1))).to eq(Date.new(2026, 1, 1))
    end
  end

  describe '.row' do
    it 'sanitizes every cell in the row' do
      row = ['Alice', '=HYPERLINK("https://evil")', 42, nil, '+1-555-0100']
      expect(described_class.row(row)).to eq(['Alice', '\'=HYPERLINK("https://evil")', 42, nil, "'+1-555-0100"])
    end

    it 'returns a new array without mutating the original' do
      row = ['=evil']
      result = described_class.row(row)
      expect(row).to eq(['=evil'])
      expect(result).to eq(["'=evil"])
    end
  end
end
