# frozen_string_literal: true

module Spree
  class CustomFieldDefinition
    module SearchCapabilities
      extend ActiveSupport::Concern

      # Columns that decide a definition's place in the search index: its
      # settings and the cf_* attribute product documents carry.
      SEARCH_INDEX_SETTINGS_ATTRIBUTES = %w[searchable sortable storefront_visible filter_key field_type resource_type].freeze

      included do
        after_commit :enqueue_search_reindex, if: :search_index_settings_changed?

        attribute :searchable, :boolean, default: false
        attribute :sortable, :boolean, default: false

        validate :search_sort_capabilities_compatible_with_type

        # `key` is already unique per (store, resource_type, namespace), but
        # both segments normalize to underscored slugs, so two different splits
        # ("a_b"/"c" vs "a"/"b_c") flatten to one filter_key — which would make
        # one of them unaddressable as a sort/filter param.
        validates :filter_key, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id, :resource_type] },
                               allow_blank: true

        scope :searchable, -> { where(searchable: true) }
        scope :sortable, -> { where(sortable: true) }
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

        # Builds API tokens from {Spree::CustomFieldDefinition.available_types}
        # (`Spree.custom_fields.types` — in-memory registry, not a DB query).
        def build_field_type_tokens(&block)
          available_types.filter_map do |klass|
            next unless block.call(klass)

            Spree::CustomField::TYPE_CLASS_TO_TOKEN[klass.to_s] || klass.to_s
          end
        end
      end

      # Public identifier for sorting and filtering product listings by this
      # custom field (+sort=cf_specs_material+,
      # +q[cf_specs_material_i_cont]=wool+). Persisted, so it can be selected,
      # indexed and ordered on; the computed form answers for a record whose
      # callback has not run yet.
      #
      # @return [String] e.g. +cf_custom_label+
      def filter_key
        self[:filter_key].presence || computed_filter_key
      end

      private

      def search_index_settings_changed?
        return false unless [resource_type, resource_type_before_last_save].include?('Spree::Product')
        return searchable? || sortable? if previously_new_record? || destroyed?

        return false unless saved_changes.keys.intersect?(SEARCH_INDEX_SETTINGS_ATTRIBUTES)

        # A field neither searchable nor sortable, before or after the change,
        # never reaches a document, so nothing in the index changes with it.
        searchable? || sortable? || searchable_before_last_save || sortable_before_last_save
      end

      def enqueue_search_reindex
        return unless search_provider_indexing?

        Spree::SearchProvider::ReindexJob.perform_later(store_id.to_s)
      end

      def search_provider_indexing?
        Spree.search_provider.constantize.indexing_required?
      rescue NameError
        false
      end

      # @return [String, nil] nil while either segment is still blank, so a
      #   half-filled record does not persist a meaningless +cf__+.
      def computed_filter_key
        return if namespace.blank? || key.blank?

        "cf_#{namespace}_#{key}"
      end

      def field_type_class
        field_type_class_name.presence&.safe_constantize
      end

      def search_sort_capabilities_compatible_with_type
        return unless searchable? || sortable?

        klass = field_type_class
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
    end
  end
end
