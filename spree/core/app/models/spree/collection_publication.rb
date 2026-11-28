module Spree
  # Per-channel publication of a collection: a collection is visible on a
  # channel's storefront only while a publication exists and its window is open.
  class CollectionPublication < Spree.base_class
    has_prefix_id :cpub

    include Spree::ChannelPublication

    publication_of :collection, inverse_of: :publications

    self.whitelisted_ransackable_attributes = %w[collection_id channel_id published_at unpublished_at]
  end
end
