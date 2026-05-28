module Spree
  class ProductPublication < Spree.base_class
    has_prefix_id :pp

    # 5.5 transitional: table keeps the legacy +spree_products_stores+ name
    # while the class moves to +ProductPublication+. The rename will happen
    # in 6.0; see docs/plans/6.0-channels-catalogs-b2b.md.
    self.table_name = 'spree_products_stores'

    belongs_to :product, class_name: 'Spree::Product', touch: true
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :channel, class_name: 'Spree::Channel', optional: true

    validates :product, :store, :channel, presence: true
    validates :product_id, uniqueness: { scope: spree_base_uniqueness_scope + %i[channel_id store_id] }
    validate :unpublished_at_after_published_at, if: -> { published_at && unpublished_at }

    before_validation :assign_channel_from_store, if: -> { channel_id.nil? && store_id.present? }
    before_validation :assign_store_from_channel, if: -> { store_id.nil? && channel_id.present? }

    scope :published, lambda {
      where('published_at IS NULL OR published_at <= ?', Time.current)
        .where('unpublished_at IS NULL OR unpublished_at > ?', Time.current)
    }

    self.whitelisted_ransackable_attributes = %w[product_id store_id channel_id published_at unpublished_at]
    self.whitelisted_ransackable_associations = %w[product store channel]

    def published?
      (published_at.nil? || published_at <= Time.current) &&
        (unpublished_at.nil? || unpublished_at > Time.current)
    end

    def refresh_metrics!
      return if product.nil?

      completed_order_ids = product.completed_orders.where(store_id: store_id).select(:id)
      variant_ids = product.variants_including_master.ids

      line_items = Spree::LineItem.joins(:order)
        .where(spree_orders: { id: completed_order_ids })
        .where(variant_id: variant_ids)

      update!(
        units_sold_count: line_items.sum(:quantity),
        revenue: line_items.sum(:pre_tax_amount)
      )
    end

    private

    def assign_channel_from_store
      self.channel = store.default_channel
    end

    def assign_store_from_channel
      self.store = channel.store
    end

    def unpublished_at_after_published_at
      return if unpublished_at > published_at

      errors.add(:unpublished_at, :must_be_after_published_at)
    end
  end
end
