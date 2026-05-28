module Spree
  class Product
    module Channels
      extend ActiveSupport::Concern

      DEPRECATED_DATE_TO_PUBLICATION_FIELD = {
        available_on:   :published_at,
        discontinue_on: :unpublished_at
      }.freeze

      # Intercepts +product.stores << store+ so the deprecated stores API still
      # produces correctly-channelled publications (with any legacy
      # +available_on+/+discontinue_on+ values applied).
      #
      # AR's default +has_many :through+ +<<+ would build a half-formed join
      # row missing the channel and the legacy dates; this extension owns the
      # build so we get a complete record.
      module StoresCollectionExtension
        def <<(*stores)
          Spree::Deprecation.warn(
            'Assigning stores via Spree::Product#stores<< is deprecated; ' \
            'use #product_publications= with explicit channel references instead. ' \
            'This bridge is removed in Spree 6.0.'
          )
          product = proxy_association.owner
          stores.flatten.each { |store| product.send(:build_publication_for_store, store) }
          self
        end
        alias_method :push,   :<<
        alias_method :append, :<<
        alias_method :concat, :<<
      end

      included do
        # No +dependent: :destroy+: Product uses +acts_as_paranoid+, so destroy
        # soft-deletes and publications outlive the product (refresh_metrics
        # handles the orphan case).
        has_many :product_publications, class_name: 'Spree::ProductPublication', autosave: true
        has_many :channels, -> { distinct }, through: :product_publications, class_name: 'Spree::Channel'

        # @deprecated Alias of {#product_publications}. Remove in Spree 6.0.
        has_many :store_products, class_name: 'Spree::ProductPublication'
        # +unscope(:order)+ drops +Spree::Store+'s +default_scope { order(:created_at) }+
        # so the +DISTINCT+ stays compatible with strict SQL modes (Postgres,
        # MySQL ONLY_FULL_GROUP_BY). Same reason +channels+ doesn't need it —
        # +Spree::Channel+ has no default ordering.
        has_many :stores, -> { unscope(:order).distinct },
                 through: :store_products, class_name: 'Spree::Store',
                 extend: StoresCollectionExtension

        before_validation :set_default_publication, if: :set_default_publication?
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

          # Reading +available_on+/+discontinue_on+/+make_active_at+ prefers the
          # current-channel publication's date and falls back to the legacy
          # Product column. Lets serializers and scopes stay one-liners while
          # the publication is the source of truth.
          define_method(legacy_attr) do
            channel = Spree::Current.channel
            publication = channel && publication_for(channel)
            publication&.public_send(publication_attr) || super()
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

      # Returns the publications for the given store, or an empty array if the product isn't published there.
      # @param store [Spree::Store] the store to find publications for
      # @return [Array<Spree::ProductPublication>] the publications for the store, or an empty array if not published
      def publications_for_store(store)
        return [] unless store

        if product_publications.loaded?
          product_publications.select { |p| p.store_id == store.id }
        else
          product_publications.where(store_id: store.id)
        end
      end

      # @deprecated Assigning stores directly is replaced by setting
      #   +product_publications=+ with explicit channels. Will be removed in
      #   Spree 6.0. The bridge clears any existing publications and rebuilds
      #   one per store on that store's +default_channel+.
      def stores=(stores)
        Spree::Deprecation.warn(
          'Assigning stores via Spree::Product#stores= is deprecated; ' \
          'use #channels= instead. ' \
          'This bridge is removed in Spree 6.0.'
        )
        product_publications.clear unless new_record?
        association(:stores).reset
        Array(stores).each { |store| build_publication_for_store(store) }
      end

      def store_ids=(ids)
        Spree::Deprecation.warn(
          'Assigning stores via Spree::Product#store_ids= is deprecated; ' \
          'use #channel_ids= instead. ' \
          'This bridge is removed in Spree 6.0.'
        )
        product_publications.clear unless new_record?
        association(:stores).reset
        Spree::Store.where(id: Array(ids).compact_blank).each { |store| build_publication_for_store(store) }
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

      def build_publication_for_store(store)
        return if store.default_channel.nil?
        return if publications_for_store(store).any?

        product_publications.build(
          { store: store, channel: store.default_channel }.merge(legacy_date_attributes)
        )
      end

      def set_default_publication?
        new_record? && product_publications.empty? && @pending_publications_params.blank?
      end

      def set_default_publication
        store = Spree::Current.store || Spree::Store.default
        return unless store
        channel = store.default_channel
        return unless channel

        product_publications.build(
          { channel: channel, store: store }.merge(legacy_date_attributes)
        )
        # If +stores=+ already populated the through cache with an empty array,
        # a freshly-built publication wouldn't show up on +product.stores+.
        association(:stores).reset
      end

      # Pulls available_on / discontinue_on / make_active_at written via the
      # deprecated Product setters into publication-side keys, so a publication
      # built later in the save cycle still carries the user's intent.
      def legacy_date_attributes
        DEPRECATED_DATE_TO_PUBLICATION_FIELD.each_with_object({}) do |(legacy, publication_attr), acc|
          value = read_attribute(legacy)
          acc[publication_attr] = value if value.present?
        end
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
          channel_id = publication_data.delete(:channel_id)

          if publication_id.present?
            publication = product_publications.find_by_param!(publication_id)
            publication.update!(publication_data)
            publication_ids_in_payload << publication.id
          elsif channel_id.present?
            channel = Spree::Channel.find_by_param!(channel_id)
            # Find-or-create on (product, channel) — auto-created publications from
            # +StoreScopedResource#set_default_store+ get reused rather than
            # colliding with the uniqueness validation.
            publication = product_publications.find_or_initialize_by(channel: channel)
            publication.store ||= channel.store
            publication.assign_attributes(publication_data)
            publication.save!
            publication_ids_in_payload << publication.id
          end
        end

        product_publications.where.not(id: publication_ids_in_payload).destroy_all if publication_ids_in_payload.any?
      end
    end
  end
end
