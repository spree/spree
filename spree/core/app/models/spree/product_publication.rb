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

    belongs_to :product, class_name: 'Spree::Product', touch: true
    belongs_to :channel, class_name: 'Spree::Channel'

    validates :product, :channel, presence: true
    validates :product_id, uniqueness: { scope: :channel_id }
    validate :unpublished_at_after_published_at, if: -> { published_at && unpublished_at }

    scope :published, lambda {
      where('published_at IS NULL OR published_at <= ?', Time.current)
        .where('unpublished_at IS NULL OR unpublished_at > ?', Time.current)
    }

    self.whitelisted_ransackable_attributes = %w[product_id channel_id published_at unpublished_at]
    self.whitelisted_ransackable_associations = %w[product channel]

    delegate :store, :store_id, to: :channel

    def published?
      (published_at.nil? || published_at <= Time.current) &&
        (unpublished_at.nil? || unpublished_at > Time.current)
    end

    private

    def unpublished_at_after_published_at
      return if unpublished_at > published_at

      errors.add(:unpublished_at, :must_be_after_published_at)
    end
  end
end
