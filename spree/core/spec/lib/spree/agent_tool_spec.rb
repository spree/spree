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
  end
end
