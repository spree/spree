module Spree
  # Per-channel publication of a category. A category is visible on a
  # channel's storefront only while it and every ancestor have an open
  # publication there (Spree::Category.published_on).
  class CategoryPublication < Spree.base_class
    has_prefix_id :ctgpub

    include Spree::ChannelPublication

    publication_of :category, inverse_of: :publications

    self.whitelisted_ransackable_attributes = %w[category_id channel_id published_at unpublished_at]
  end
end
