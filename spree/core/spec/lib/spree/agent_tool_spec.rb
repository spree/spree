require 'spec_helper'

RSpec.describe Spree::AgentTool do
  let(:read) { Class.new(described_class) }
  let(:write) { Class.new(described_class) { mutating! } }
  let(:additive_write) do
    Class.new(described_class) do
      mutating!
      additive!
    end
  end

  describe '.destructive?' do
    it 'is false for a read' do
      expect(read).not_to be_destructive
    end

    it 'is true for a write that does not say it only adds' do
      expect(write).to be_destructive
    end

    it 'is false for a write declared additive' do
      expect(additive_write).not_to be_destructive
    end

    it 'is inherited, so a subclass of a destructive tool stays destructive' do
      expect(Class.new(write)).to be_destructive
    end

    it 'makes a subclass of an additive tool declare additive itself' do
      expect(Class.new(additive_write)).to be_destructive
    end
  end

  describe '.input_schema' do
    def items_for(items)
      tool = Class.new(described_class) { param :values, type: :array, items: items }
      tool.input_schema.dig('properties', 'values', 'items')
    end

    it 'describes an array of one type with that type' do
      expect(items_for(:object)).to eq('type' => 'object')
    end

    it 'describes an array of several types as any one of them' do
      expect(items_for(%i[string object])).to eq('anyOf' => [{ 'type' => 'string' }, { 'type' => 'object' }])
    end

    it 'falls back to strings when no type is given' do
      expect(items_for(nil)).to eq('type' => 'string')
      expect(items_for([])).to eq('type' => 'string')
    end
  end
end
