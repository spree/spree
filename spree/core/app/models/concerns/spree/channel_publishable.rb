module Spree
  # A record merchants publish per sales channel: a product, category or
  # collection. Its publications are written as one set, a row per channel
  # (+channel_id+, optional +published_at+ / +unpublished_at+, or the +id+ of
  # an existing publication). Channels left out are unpublished; another
  # store's channels are ignored. A saved record applies the set at once; a
  # new one applies it after create, once it has an id. The publication side
  # is Spree::ChannelPublication.
  module ChannelPublishable
    extend ActiveSupport::Concern

    included do
      class_attribute :publications_association, instance_writer: false
      class_attribute :channel_publication_events, instance_writer: false, default: false

      after_create :apply_pending_publications, if: -> { @pending_publications }
      validate :publications_set_applies
    end

    class_methods do
      # Makes a record publishable per channel. The model declares the
      # publications association itself; this adds the channels through it
      # and its set writer.
      #
      # @param name [Symbol] the publications association, as the API names it
      # @param events [Boolean] whether publishing sends `<record>.published`
      #   and unpublishing `<record>.unpublished`, with the channel id
      # @param publish_on_active_channels [Boolean] whether a record created
      #   without a publications set goes live on every active channel of its store
      # @return [void]
      def publishable_on_channels(name, events: false, publish_on_active_channels: false)
        has_many :channels, -> { distinct }, through: name, class_name: 'Spree::Channel'

        self.publications_association = name
        self.channel_publication_events = events
        publishes_events :published, :unpublished if events

        define_method(:"#{name}=") do |rows|
          if rows.nil? || rows.first.is_a?(Spree::Base)
            super(rows)
          else
            @publications_assigned = true
            @pending_publications = rows.map { |row| row.to_h.with_indifferent_access }
            apply_publications_now if persisted?
          end
        end

        return unless publish_on_active_channels

        after_create :publish_on_active_channels, unless: :publications_assigned?
        after_create_commit :announce_active_channel_publications, unless: :publications_assigned?
      end

      # Records published on the channel with their window open.
      #
      # @param channel [Spree::Channel, nil]
      # @return [ActiveRecord::Relation]
      def published_on(channel)
        reflection = reflect_on_association(publications_association)
        where(id: reflection.klass.published.where(channel_id: channel&.id).select(reflection.foreign_key))
      end

      # Called after records are published on or unpublished from channels
      # in bulk, which skips their callbacks.
      #
      # @param ids [Array<String>]
      # @return [void]
      def refresh_after_publishing(ids)
        where(id: ids).touch_all
      end

      # Publishes every record that has no publication on every active
      # channel of its store, without events. The upgrade step for a record
      # type that was public before it was published per channel.
      #
      # @param batch_size [Integer]
      # @return [Integer] the number of records published
      def backfill_publications(batch_size: 1_000)
        published = 0

        Spree::Store.find_each do |store|
          channels = store.channels.active
          next unless channels.exists?

          where(store_id: store.id).where.missing(publications_association).in_batches(of: batch_size) do |batch|
            ids = batch.ids
            # All or none of a batch's channels, so a rerun finds an interrupted batch unpublished.
            ApplicationRecord.transaction { channels.publish_records(self, ids, publish_events: false) }
            published += ids.size
          end
        end

        published
      end
    end

    # @return [Boolean] whether the save carries a publications set
    def publications_assigned?
      @publications_assigned == true
    end

    # The publication on the channel, or nil when the record isn't published there.
    #
    # @param channel [Spree::Channel, nil]
    # @return [Spree::ChannelPublication, nil]
    def publication_for(channel)
      return nil unless channel

      publications = public_send(publications_association)
      if read_association_in_memory?(publications_association)
        publications.find { |publication| publication.channel_id == channel.id }
      else
        publications.find_by(channel_id: channel.id)
      end
    end

    private

    # A set that fails to apply on a saved record is rolled back and reported
    # when the record is next validated, so `update` answers false.
    def apply_publications_now
      @publications_set_errors = nil
      ApplicationRecord.transaction { apply_pending_publications }
    rescue ActiveRecord::RecordInvalid
      @publications_set_errors = errors[publications_association].dup
    end

    def publications_set_applies
      @publications_set_errors&.each { |message| errors.add(publications_association, message) }
    end

    def apply_pending_publications
      rows = @pending_publications
      @pending_publications = nil
      publications = public_send(publications_association)
      existing = publications.to_a
      channels_by_id = store.channels.where(id: rows.filter_map { |row| decode_publication_channel_id(row[:channel_id]) }).
                       index_by { |channel| channel.id.to_s }

      kept = rows.filter_map do |row|
        publication = publication_for_row(row, existing, channels_by_id, publications)
        next unless publication

        save_publication!(publication, row.slice(:published_at, :unpublished_at))
      end

      (existing - kept).each(&:destroy!)
    end

    # A row names an existing publication by id, or a channel. The channel of
    # an existing publication cannot change.
    def publication_for_row(row, existing, channels_by_id, publications)
      if row[:id].present?
        existing.find { |publication| [publication.id.to_s, publication.prefixed_id].include?(row[:id].to_s) }
      elsif row[:channel_id].present?
        channel = channels_by_id[decode_publication_channel_id(row[:channel_id]).to_s]
        channel && (existing.find { |publication| publication.channel_id == channel.id } || publications.build(channel: channel))
      else
        errors.add(publications_association, :blank)
        raise ActiveRecord::RecordInvalid, self
      end
    end

    def save_publication!(publication, window)
      return publication if publication.update(window)

      publication.errors.each { |error| errors.add(publications_association, error.full_message) }
      raise ActiveRecord::RecordInvalid, self
    end

    def decode_publication_channel_id(value)
      return if value.blank?

      Spree::Channel.decode_own_prefixed_id(value.to_s) || value
    end

    def publish_on_active_channels
      @active_channels = store.channels.active.to_a
      Spree::Channel.where(id: @active_channels.map(&:id)).publish_records(self.class, id, publish_events: false)
    end

    def announce_active_channel_publications
      return unless channel_publication_events

      @active_channels&.each do |channel|
        publish_event("#{event_prefix}.published", nil, { channel_id: channel.prefixed_id })
      end
      @active_channels = nil
    end
  end
end
