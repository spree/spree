require 'spec_helper'

RSpec.describe Spree::Currency, type: :model do
  describe '#name' do
    it 'returns the display name for a known code' do
      expect(described_class.new(code: 'EUR').name).to eq('Euro')
    end

    it 'returns the upcased code for an unknown currency' do
      expect(described_class.new(code: 'zzz').name).to eq('ZZZ')
    end
  end

  describe '#label' do
    it 'formats code and name' do
      expect(described_class.new(code: 'EUR').label).to eq('EUR — Euro')
    end

    it 'falls back to the bare code for an unknown currency' do
      expect(described_class.new(code: 'zzz').label).to eq('ZZZ')
    end
  end

  describe 'string-likeness' do
    it 'stringifies to the upcased code' do
      expect(described_class.new(code: 'usd').to_s).to eq('USD')
    end

    it 'is equal to another currency with the same code' do
      expect(described_class.new(code: 'usd')).to eql(described_class.new(code: 'USD'))
    end
  end
end
