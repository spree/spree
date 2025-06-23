require 'spec_helper'

RSpec.describe Spree::PageSections::FeaturedTaxon do
  describe '#posts' do
    let!(:posts) { create_list(:post, 3, published_at: nil) }
    let!(:published_posts) { create_list(:post, 3, published_at: Time.current) }
    let(:section) { build(:featured_posts_page_section, preferred_max_posts_to_show: 2) }

    it 'returns newsest posts with limit' do
      expect(section.posts).not_to include(posts[0])
      expect(section.posts).not_to include(posts[1])
      expect(section.posts).to include(published_posts[1])
      expect(section.posts).to include(published_posts[2])
    end
  end
end
