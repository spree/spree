module Spree
  class Product
    module Channels
      extend ActiveSupport::Concern

      DEPRECATED_DATE_TO_PUBLICATION_FIELD = {
        available_on:   :published_at,
        discontinue_on: :unpublished_at
      }.freeze

      included do
        belongs_to :store, class_name: 'Spree::Store', optional: true

        # No +dependent: :destroy+: Product uses +acts_as_paranoid+, so destroy
        # soft-deletes and publications outlive the product.
        has_many :product_publications, class_name: 'Spree::ProductPublication', autosave: true
        has_many :channels, -> { distinct }, through: :product_publications, class_name: 'Spree::Channel'

        # Legacy Rails admin alias. The admin form submits
        # +legacy_product_publications_attributes+ (with +_destroy+ flags and
        # +reject_if+ semantics); the v3 API submits +product_publications+
        # and goes through the custom writer below. Two names, one table —
        # no +dependent:+ for the same +acts_as_paranoid+ reason as above.
        has_many :legacy_product_publications, class_name: 'Spree::ProductPublication',
                                               foreign_key: :product_id, autosave: true
        accepts_nested_attributes_for :legacy_product_publications,
                                      allow_destroy: true,
                                      reject_if: ->(attrs) { attrs[:channel_id].blank? }

        before_validation :assign_default_store, if: -> { store.nil? }
        after_create :apply_pending_publications, if: :pending_publications?

        DEPRECATED_DATE_TO_PUBLICATION_FIELD.each do |legacy_attr, publication_attr|
          define_method("#{legacy_attr}=") do |value|
            Spree::Deprecation.warn(
              "Spree::Product##{legacy_attr}= is deprecated; set #{publication_attr} on " \
              "ProductPublication instead (writes to every channel's publication). "
            )
            super(value)
            product_publications.each { |publication| publication.public_send("#{publication_attr}=", value) }
          end

          # Reading +available_on+/+discontinue_on+ prefers the current-channel
          # publication's date and falls back to the legacy Product column
          # whenever the publication's value is nil. This 5.5 transition
          # behavior is dropped in 6.0 when the legacy columns are removed.
          define_method(legacy_attr) do
            channel = Spree::Current.channel
            publication = channel && publication_for(channel)
            (publication && publication.public_send(publication_attr)) || super()
          end
        end
      end

      # Returns the publication for the given channel, or nil if the product isn't published there.
      # @param channel [Spree::Channel] the channel to find the publication for
      # @return [Spree::ProductPublication, nil] the publication for the channel, or nil if not published
      def publication_for(channel)
        return nil unless channel

        if product_publications.loaded?
          product_publications.find { |p| p.channel_id == channel.id }
        else
          product_publications.find_by(channel_id: channel.id)
        end
      end

      # Syncs product publications from an array of hashes.
      # Creates new publications, updates existing ones (matched by +:id+ or
      # +:channel_id+), and removes ones absent from the payload. An empty
      # array detaches the product from every channel.
      # @param publications_params [Array<Hash>] array of publication attribute hashes
      # @return [void]
      def product_publications=(publications_params)
        return super if publications_params.nil?
        return super if publications_params.respond_to?(:first) && publications_params.first.is_a?(Spree::ProductPublication)

        if new_record?
          @pending_publications_params = publications_params
          return
        end

        apply_product_publications(publications_params)
      end

      private

      def assign_default_store
        self.store ||= Spree::Current.store || Spree::Store.default
      end

      def pending_publications?
        @pending_publications_params.present?
      end

      def apply_pending_publications
        return unless @pending_publications_params

        apply_product_publications(@pending_publications_params)
        @pending_publications_params = nil
      end

      def apply_product_publications(publications_params)
        publication_ids_in_payload = []

        publications_params.each do |publication_data|
          publication_data = publication_data.to_h.with_indifferent_access
          publication_id = publication_data.delete(:id)
          channel_id = decode_publication_channel_id(publication_data[:channel_id])

          if publication_id.present?
            decoded_id = Spree::PrefixedId.prefixed_id?(publication_id) ?
                           Spree::PrefixedId.decode_prefixed_id(publication_id) :
                           publication_id
            publication = product_publications.find_by(id: decoded_id)
            next unless publication

            # Channel is immutable; ignore any rebind attempt.
            publication.update!(publication_data.slice(:published_at, :unpublished_at))
            publication_ids_in_payload << publication.id
          elsif channel_id.present?
            # Upsert by channel_id so repeat submissions are idempotent
            # against the unique (product_id, channel_id) index.
            publication = product_publications.find_or_initialize_by(channel_id: channel_id)
            publication.assign_attributes(publication_data.slice(:published_at, :unpublished_at))
            publication.save!
            publication_ids_in_payload << publication.id
          end
        end

        product_publications.where.not(id: publication_ids_in_payload).destroy_all
      end

      def decode_publication_channel_id(value)
        return nil if value.blank?
        return value unless Spree::PrefixedId.prefixed_id?(value)

        Spree::PrefixedId.decode_prefixed_id(value) || value
      end
    end
  end
end
