module Spree
  module Publications
    # The create-workflow step that publishes a new category or collection on
    # every active channel of its store, unless its attributes carry a
    # `publications` set. The including workflow names the record
    # `publishable`.
    module PublishOnActiveChannels
      private

      def publish_on_active_channels
        return if publishable.publications_assigned?

        @published_channels = publishable.store.channels.active.to_a
        Spree::Channel.where(id: @published_channels.map(&:id)).publish_records(publishable.class, publishable.id, publish_events: false)
      end

      # Deferred so a caller's transaction that rolls back announces nothing.
      def announce_publications
        channels = @published_channels
        record = publishable
        return if channels.blank? || !record.channel_publication_events

        ActiveRecord.after_all_transactions_commit do
          channels.each { |channel| record.publish_event("#{record.event_prefix}.published", nil, { channel_id: channel.prefixed_id }) }
        end
      end
    end
  end
end
