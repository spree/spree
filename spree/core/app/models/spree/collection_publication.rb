module Spree
  # Per-channel publication of a collection, the same shape as
  # Spree::ProductPublication: a collection is visible on a channel's
  # storefront only while a publication exists and its window is open.
  class CollectionPublication < Spree.base_class
    has_prefix_id :cpub

    include Spree::PublicationWindow

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :publications, touch: true
    belongs_to :channel, class_name: 'Spree::Channel', inverse_of: :collection_publications

    validates :collection_id, uniqueness: { scope: spree_base_uniqueness_scope + [:channel_id] }
    validate :channel_belongs_to_collection_store, if: -> { collection && channel }

    after_create_commit -> { publish_collection_event('collection.published') }
    after_destroy_commit -> { publish_collection_event('collection.unpublished') }

    self.whitelisted_ransackable_attributes = %w[collection_id channel_id published_at unpublished_at]

    private

    def channel_belongs_to_collection_store
      return if channel.store_id == collection.store_id

      errors.add(:channel, :invalid)
    end

    def publish_collection_event(name)
      collection.publish_event(name, nil, { channel_id: channel.prefixed_id })
    end
  end
end
