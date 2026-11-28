module Spree
  # A record's publication on one sales channel, with an optional window:
  # +published_at+ (null means immediately) to +unpublished_at+ (null means
  # never). Shared by product, category and collection publications so all
  # three agree on what is live on a channel. The record side is
  # Spree::ChannelPublishable.
  module ChannelPublication
    extend ActiveSupport::Concern

    included do
      belongs_to :channel, class_name: 'Spree::Channel'

      validate :unpublished_at_after_published_at, if: -> { published_at && unpublished_at }

      scope :published, lambda {
        where('published_at IS NULL OR published_at <= ?', Time.current).
          where('unpublished_at IS NULL OR unpublished_at > ?', Time.current)
      }

      delegate :store, :store_id, to: :channel
    end

    class_methods do
      # Names the record this publication puts on a channel.
      #
      # @param name [Symbol] the association, e.g. +:category+
      # @param inverse_of [Symbol] the record's publications association
      # @return [void]
      def publication_of(name, inverse_of:)
        belongs_to name, class_name: "Spree::#{name.to_s.classify}", inverse_of: inverse_of, touch: true
        alias_method :publishable, name

        validates :"#{name}_id", uniqueness: { scope: spree_base_uniqueness_scope + [:channel_id] }
        validate :channel_belongs_to_publishable_store, if: -> { publishable && channel }

        after_create_commit -> { publish_publishable_event('published') }
        after_destroy_commit -> { publish_publishable_event('unpublished') }
      end
    end

    # @return [Boolean] whether the window is open now
    def published?
      (published_at.nil? || published_at <= Time.current) &&
        (unpublished_at.nil? || unpublished_at > Time.current)
    end

    private

    def unpublished_at_after_published_at
      return if unpublished_at > published_at

      errors.add(:unpublished_at, :must_be_after_published_at)
    end

    def channel_belongs_to_publishable_store
      return if channel.store_id == publishable.store_id

      errors.add(:channel, :invalid)
    end

    def publish_publishable_event(action)
      return unless publishable.class.channel_publication_events

      publishable.publish_event("#{publishable.event_prefix}.#{action}", nil, { channel_id: channel.prefixed_id })
    end
  end
end
