# frozen_string_literal: true

module Spree
  class MetafieldDefinition
    module SearchCapabilities
      extend ActiveSupport::Concern

      SEARCH_SCHEMA_FIELDS = %w[
        searchable
        sortable
        namespace
        key
        resource_type
        metafield_type
      ].freeze

      included do
        attribute :searchable, :boolean, default: false
        attribute :sortable, :boolean, default: false

        validate :search_sort_capabilities_compatible_with_type

        scope :searchable, -> { where(searchable: true) }
        scope :sortable, -> { where(sortable: true) }

        after_commit :enqueue_search_schema_refresh, on: %i[create update], if: :search_schema_relevant_change?
        after_commit :enqueue_search_schema_refresh_on_destroy, on: :destroy, if: :search_schema_participant?
      end

      class_methods do
        # @return [Array<String>] API field_type tokens whose STI class is searchable
        def searchable_field_type_tokens
          @searchable_field_type_tokens ||= build_field_type_tokens(&:searchable?)
        end

        # @return [Array<String>] API field_type tokens whose STI class is sortable
        def sortable_field_type_tokens
          @sortable_field_type_tokens ||= build_field_type_tokens(&:sortable?)
        end

        private

        # Builds API tokens from {Spree::MetafieldDefinition.available_types}
        # (`Spree.metafields.types` — in-memory registry, not a DB query).
        def build_field_type_tokens(&block)
          available_types.filter_map do |klass|
            next unless block.call(klass)

            Spree::Metafield::TYPE_CLASS_TO_TOKEN[klass.to_s] || klass.to_s
          end
        end
      end

      # SearchProvider document key. Namespace is length-prefixed so
      # (a_b, c) and (a, b_c) cannot collide as the same mf_* attribute.
      # @return [String] e.g. +mf_6_custom_label+
      def search_key
        "mf_#{namespace.to_s.length}_#{namespace}_#{key}"
      end

      private

      def metafield_type_class
        metafield_type.presence&.safe_constantize
      end

      def search_sort_capabilities_compatible_with_type
        return unless searchable? || sortable?

        klass = metafield_type_class
        return if klass.nil?

        %i[searchable sortable].each do |capability|
          next unless public_send("#{capability}?")
          next if klass.public_send("#{capability}?")

          errors.add(capability, capability_error_message(capability))
        end
      end

      def capability_error_message(capability)
        labels = self.class
                     .public_send("#{capability}_field_type_tokens")
                     .map { |token| token.tr('_', ' ') }
                     .join(', ')

        "is only supported for field types: #{labels}"
      end

      def search_schema_relevant_change?
        return true if previously_new_record?

        (saved_changes.keys & SEARCH_SCHEMA_FIELDS).any?
      end

      def search_schema_participant?
        searchable? || sortable?
      end

      def enqueue_search_schema_refresh_on_destroy
        enqueue_search_schema_refresh
      end

      def enqueue_search_schema_refresh
        # Drop the in-process registry immediately so the next request sees
        # current definitions. External index settings (Meilisearch) refresh async.
        Spree::Dependencies.search_metafield_attributes_class.clear_cache!

        return unless Spree.search_provider.safe_constantize&.indexing_required?

        Spree::SearchProvider::RefreshMetafieldSchemaJob.perform_later
      end
    end
  end
end