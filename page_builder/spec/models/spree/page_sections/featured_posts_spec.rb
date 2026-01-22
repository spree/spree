require 'spec_helper'

RSpec.describe Spree::PageSections::FeaturedPosts do
  describe '#posts' do
    subject(:result) { section.posts }

    let!(:posts) { create_list(:post, 3, published_at: nil) }
    let!(:published_posts) { create_list(:post, 3, published_at: Time.current) }
    let(:section) { build(:featured_posts_page_section, preferred_max_posts_to_show: 2) }

    it 'returns newsest posts with limit' do
      expect(result).not_to include(*posts)
      expect(result).to eq(published_posts.sort_by(&:published_at).reverse!.first(2))
    end
  end
end
