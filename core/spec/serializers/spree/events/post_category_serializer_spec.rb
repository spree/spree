# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PostCategorySerializer do
  let(:store) { create(:store) }
  let(:post_category) { create(:post_category, store: store, title: 'News') }

  subject { described_class.serialize(post_category) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(post_category.id)
      expect(subject[:title]).to eq('News')
      expect(subject[:slug]).to eq(post_category.slug)
    end

    it 'includes store_id' do
      expect(subject[:store_id]).to eq(store.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
