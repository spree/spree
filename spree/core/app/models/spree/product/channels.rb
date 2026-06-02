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

        # +accepts_nested_attributes_for+ enables the legacy Rails admin form
        # to submit publication windows via +product_publications_attributes=+.
        # The SPA's API path uses the explicit hash-array setter defined below
        # (+product_publications=+); the two coexist on different keys.
        accepts_nested_attributes_for :product_publications,
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
      # Creates new publications, updates existing ones (matched by :id), and removes
      # ones absent from the payload. Mirrors +Product#variants=+.
      # @param publications_params [Array<Hash>] array of publication attribute hashes
      # @return [void]
      def product_publications=(publications_params)
        return super if publications_params.blank? || publications_params.first.is_a?(Spree::ProductPublication)

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

      # SPA write contract for +product.product_publications=+: the caller
      # sends the FULL desired set of publications. Rows present become
      # creates/updates; rows absent get destroyed. Mass-delete is safe
      # because the only caller (+<PublishingCard>+ in the dashboard) drives
      # the array via +useFieldArray+ and always submits the complete state.
      # The Rails admin uses +product_publications_attributes=+ (nested
      # attributes) instead — that path uses explicit +_destroy: '1'+ flags
      # and never reaches this method.
      def apply_product_publications(publications_params)
        publication_ids_in_payload = []

        publications_params.each do |publication_data|
          publication_data = publication_data.to_h.with_indifferent_access
          publication_id = publication_data.delete(:id)

          if publication_id.present?
            decoded_id = Spree::PrefixedId.prefixed_id?(publication_id) ?
                           Spree::PrefixedId.decode_prefixed_id(publication_id) :
                           publication_id
            publication = product_publications.find_by(id: decoded_id)
            next unless publication

            # Channel is immutable on a publication — silently drop any
            # caller attempt to rebind it. Re-publish on a different channel
            # is a destroy + create, not an update.
            publication.update!(publication_data.slice(:published_at, :unpublished_at))
            publication_ids_in_payload << publication.id
          elsif publication_data[:channel_id].present?
            new_publication = product_publications.create!(
              publication_data.slice(:channel_id, :published_at, :unpublished_at)
            )
            publication_ids_in_payload << new_publication.id
          end
        end

        product_publications.where.not(id: publication_ids_in_payload).destroy_all
      end
    end
  end
end
