# frozen_string_literal: true

require 'spec_helper'

describe Spree::Metafields::ShortText, type: :model do
  describe '.searchable? / .sortable?' do
    it 'is searchable and sortable' do
      expect(described_class.searchable?).to eq(true)
      expect(described_class.sortable?).to eq(true)
    end
  end
end
