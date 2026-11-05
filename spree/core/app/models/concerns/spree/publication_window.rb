module Spree
  # The optional window a publication is live in: +published_at+ (null means
  # immediately) to +unpublished_at+ (null means never). Shared by product
  # and collection publications so both agree on what is live on a channel.
  module PublicationWindow
    extend ActiveSupport::Concern

    included do
      validate :unpublished_at_after_published_at, if: -> { published_at && unpublished_at }

      scope :published, lambda {
        where('published_at IS NULL OR published_at <= ?', Time.current).
          where('unpublished_at IS NULL OR unpublished_at > ?', Time.current)
      }

      delegate :store, :store_id, to: :channel
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
  end
end
