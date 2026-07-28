# frozen_string_literal: true

require 'spec_helper'

describe Spree::Metafields::LongText, type: :model do
  describe '.searchable? / .sortable?' do
    it 'is searchable but not sortable' do
      expect(described_class.searchable?).to eq(true)
      expect(described_class.sortable?).to eq(false)
    end
  end
end
