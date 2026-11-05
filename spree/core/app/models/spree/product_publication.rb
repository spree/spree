module Spree
  # Per-channel publication record. A Product is "published" on a Channel when
  # a ProductPublication exists for that pair; the optional window
  # (+published_at+/+unpublished_at+) gates customer visibility.
  #
  # The owning Store is derived via +channel.store+ — no +store_id+ column
  # lives on this table. Historic core had a +spree_products_stores+ join that
  # also carried the Product↔Store relation; in 5.5+ that responsibility moves
  # onto +Spree::Product#store_id+ directly, leaving this table single-purpose.
  class ProductPublication < Spree.base_class
    has_prefix_id :pp

    include Spree::PublicationWindow

    belongs_to :product, class_name: 'Spree::Product', touch: true
    belongs_to :channel, class_name: 'Spree::Channel'

    validates :product_id, uniqueness: { scope: :channel_id }

    self.whitelisted_ransackable_attributes = %w[product_id channel_id published_at unpublished_at]
    self.whitelisted_ransackable_associations = %w[product channel]
  end
end
