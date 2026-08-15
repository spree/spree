require 'spec_helper'

describe Spree::State do
  describe '.for_country' do
    it 'lists the subdivisions of a country' do
      states = described_class.for_country('US')

      expect(states.map(&:abbr)).to include('CA', 'NY', 'MD')
      expect(states.find { |state| state.abbr == 'CA' }.name).to eq('California')
    end

    it 'is empty for a country with no subdivisions' do
      expect(described_class.for_country('HK')).to be_empty
    end
  end

  describe '.resolve' do
    it 'finds a subdivision by code or name' do
      expect(described_class.resolve('US', 'CA').name).to eq('California')
      expect(described_class.resolve('US', 'California').abbr).to eq('CA')
    end

    it 'finds a subdivision by a code ISO has since retired' do
      expect(described_class.resolve('ZA', 'GT').abbr).to eq('GP')
    end

    it 'is nil when nothing matches' do
      expect(described_class.resolve('US', 'Nonsense')).to be_nil
    end
  end

  describe '#country' do
    it 'reads back the country it belongs to' do
      expect(described_class.resolve('US', 'CA').country.iso).to eq('US')
    end
  end

  # A subdivision code is only unique within its country, so both halves count.
  describe 'equality' do
    it 'is equal to the same subdivision of the same country' do
      expect(described_class.resolve('US', 'CA')).to eq(described_class.resolve('US', 'CA'))
    end

    it 'is not equal to the same code in another country' do
      expect(described_class.resolve('US', 'CA')).not_to eq(described_class.resolve('IT', 'CA'))
    end

    it 'deduplicates by country and code' do
      states = [described_class.resolve('US', 'CA'), described_class.resolve('US', 'CA')]

      expect(states.uniq.size).to eq(1)
    end
  end
end
