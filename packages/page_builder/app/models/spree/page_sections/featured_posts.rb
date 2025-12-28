module Spree
  module PageSections
    class FeaturedPosts < Spree::PageSection
      before_validation :make_heading_size_valid
      before_validation :make_max_posts_to_show_valid
      before_validation :make_alignment_valid
      before_validation :make_posts_to_show_valid

      preference :heading, :string, default: ''
      preference :heading_size, :string, default: 'large'
      preference :heading_alignment, :string, default: 'left'
      preference :description_alignment, :string, default: 'left'
      preference :posts_to_show, :string, default: 'newest'
      preference :max_posts_to_show, :integer, default: 4

      def icon_name
        'news'
      end

      def posts
        Spree::Post.published.by_newest.limit(preferred_max_posts_to_show)
      end

      private

      def make_posts_to_show_valid
        self.preferred_posts_to_show = 'newest' unless %w[newest most_popular].include?(preferred_posts_to_show)
      end

      def make_alignment_valid
        self.preferred_heading_alignment = 'left' unless %w[left center right].include?(preferred_heading_alignment)
        self.preferred_description_alignment = 'left' unless %w[left center right].include?(preferred_description_alignment)
      end

      def make_max_posts_to_show_valid
        self.preferred_max_posts_to_show = 2 if preferred_max_posts_to_show < 2
        self.preferred_max_posts_to_show = 8 if preferred_max_posts_to_show > 8
      end

      def make_heading_size_valid
        self.preferred_heading_size = 'small' unless %w[small medium large].include?(preferred_heading_size)
      end
    end
  end
end
