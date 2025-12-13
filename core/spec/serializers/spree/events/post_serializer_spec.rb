# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::PostSerializer do
  let(:store) { create(:store) }
  let(:post_category) { create(:post_category, store: store) }
  let(:author) { create(:admin_user) }
  let(:post) do
    create(:post,
           store: store,
           post_category: post_category,
           author: author,
           title: 'Test Post',
           published_at: Time.current)
  end

  subject { described_class.serialize(post) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(post.id)
      expect(subject[:title]).to eq('Test Post')
      expect(subject[:slug]).to eq(post.slug)
    end

    it 'includes meta fields' do
      expect(subject).to have_key(:meta_title)
      expect(subject).to have_key(:meta_description)
    end

    it 'includes published_at' do
      expect(subject[:published_at]).to be_present
    end

    it 'includes deleted_at' do
      expect(subject).to have_key(:deleted_at)
    end

    it 'includes foreign keys' do
      expect(subject[:author_id]).to eq(author.id)
      expect(subject[:post_category_id]).to eq(post_category.id)
      expect(subject[:store_id]).to eq(store.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
