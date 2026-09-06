module Spree
  module Purchase
    module Channel
      extend ActiveSupport::Concern

      included do
        belongs_to :channel, class_name: 'Spree::Channel'

        before_validation :ensure_channel_presence

        # A channel is a surface of one store, so a purchase can only be made
        # on its own store's. Guards every write path rather than the service
        # that happens to build the record.
        validate :channel_belongs_to_store, if: -> { channel_id.present? && store_id.present? }
      end

      def ensure_channel_presence
        return if channel_id.present?

        self.channel = store&.default_channel
      end

      private

      def channel_belongs_to_store
        return if channel.nil? || channel.store_id == store_id

        errors.add(:channel, :must_belong_to_same_store)
      end
    end
  end
end
