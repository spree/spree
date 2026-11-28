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

        include Spree::ChannelPublishable

        # No +dependent: :destroy+: Product uses +acts_as_paranoid+, so destroy
        # soft-deletes and publications outlive the product.
        # +inverse_of: :product+ is what wires the parent into a child built off
        # an unsaved Product (via +accepts_nested_attributes_for+ on the legacy
        # alias below). Without it the child fails +validates :product,
        # presence: true+ on +create+. Declared on both associations to keep
        # the two in-memory caches symmetric (V-3454).
        has_many :product_publications, class_name: 'Spree::ProductPublication',
                                        inverse_of: :product, autosave: true
        publishable_on_channels :product_publications

        # Publishing changes what a product's listings and search documents show.
        def self.refresh_after_publishing(ids)
          products = where(id: ids)
          products.touch_all
          # `to_a` once: `touch_all` does not load the relation, so iterating it
          # afterwards would re-run the query.
          products.to_a.each(&:enqueue_search_index)
        end

        # Legacy Rails admin alias. The admin form submits
        # +legacy_product_publications_attributes+ (with +_destroy+ flags and
        # +reject_if+ semantics); the v3 API submits +product_publications+
        # and goes through the set writer (Spree::ChannelPublishable). Two names, one table —
        # no +dependent:+ for the same +acts_as_paranoid+ reason as above.
        has_many :legacy_product_publications, class_name: 'Spree::ProductPublication',
                                               foreign_key: :product_id,
                                               inverse_of: :product, autosave: true
        accepts_nested_attributes_for :legacy_product_publications,
                                      allow_destroy: true,
                                      reject_if: ->(attrs) { attrs[:channel_id].blank? }

        before_validation :assign_default_store, if: -> { store.nil? }

        DEPRECATED_DATE_TO_PUBLICATION_FIELD.each do |legacy_attr, publication_attr|
          define_method("#{legacy_attr}=") do |value|
            Spree::Deprecation.warn(
              "Spree::Product##{legacy_attr}= is deprecated; set #{publication_attr} on " \
              "ProductPublication instead (writes to every channel's publication). "
            )
            write_publication_date(legacy_attr, value)
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

      private

      # Writes a legacy date column together with the matching date on every
      # channel's publication, so the two never disagree.
      def write_publication_date(legacy_attr, value)
        write_attribute(legacy_attr, value)
        publication_attr = DEPRECATED_DATE_TO_PUBLICATION_FIELD.fetch(legacy_attr.to_sym)
        product_publications.each { |publication| publication.public_send("#{publication_attr}=", value) }
      end

      def assign_default_store
        self.store ||= Spree::Current.store || Spree::Store.default
      end

      # The store a product's associations (categories, channels) must belong
      # to. Falls back to the request/default store for not-yet-persisted
      # products whose `store` hasn't been assigned.
      def assignable_store
        store || Spree::Current.store || Spree::Store.default
      end
    end
  end
end
