# frozen_string_literal: true

module Spree
  module SearchProvider
    # Product custom_field definitions that participate in search/sort.
    class CustomFieldSchema
      # Ransack-style predicates accepted per field type. Mirrors the operator
      # sets the admin dashboard's filter panel offers for string/number columns
      # (see packages/dashboard-core/src/components/table-toolbar.tsx).
      TEXT_FILTER_PREDICATES = %w[i_cont cont eq not_eq start end present blank].freeze
      NUMBER_FILTER_PREDICATES = %w[eq gt gteq lt lteq present blank].freeze

      # Longest first so a key ending in +_i_cont+ isn't mis-split as the
      # shorter +_cont+ against a definition keyed +..._i+.
      ORDERED_FILTER_PREDICATES = (TEXT_FILTER_PREDICATES | NUMBER_FILTER_PREDICATES).
                                  sort_by { |predicate| -predicate.length }.freeze

      # @return [Hash{String => Spree::CustomFieldDefinition}]
      def entries
        @entries ||= product_definitions.index_by(&:filter_key)
      end

      # @return [Array<String>]
      def searchable_attribute_keys
        @searchable_attribute_keys ||= entries.each_value.filter_map do |definition|
          definition.filter_key if definition.searchable?
        end
      end

      # @return [Array<String>]
      def sortable_attribute_keys
        @sortable_attribute_keys ||= entries.each_value.filter_map do |definition|
          definition.filter_key if definition.sortable?
        end
      end

      # @param attribute_key [String]
      # @return [Spree::CustomFieldDefinition, nil]
      def entry_for(attribute_key)
        entries[attribute_key.to_s]
      end

      # Every schema attribute accepts filters — values are already indexed
      # for search/sort, so filtering rides on the same document keys.
      #
      # @return [Array<String>]
      def filterable_attribute_keys
        @filterable_attribute_keys ||= entries.keys
      end

      # @return [Array<String>]
      def sort_ids
        @sort_ids ||= sortable_attribute_keys.flat_map { |key| [key, "-#{key}"] }
      end

      # @return [Array<Hash>] +{ id:, label: }+
      def sort_options
        @sort_options ||= entries.each_value.select(&:sortable?).flat_map do |definition|
          key = definition.filter_key
          name = definition.name.presence || key

          [
            { id: key, label: sort_option_label(name, definition.field_type, :asc) },
            { id: "-#{key}", label: sort_option_label(name, definition.field_type, :desc) }
          ]
        end
      end

      # @param sort [String, nil]
      # @return [Hash, nil] { attribute:, direction: 'asc'|'desc' }
      def parse_sort(sort)
        value = sort.to_s.strip
        return if value.blank?

        attribute = value.delete_prefix('-')
        definition = entry_for(attribute)
        return unless definition&.sortable?

        {
          attribute: attribute,
          direction: value.start_with?('-') ? 'desc' : 'asc'
        }
      end

      # Splits a Ransack-style predicate key (e.g. +cf_custom_label_i_cont+)
      # into the definition it targets and the predicate. Both search keys and
      # predicates contain underscores, so predicates are tried longest-first —
      # otherwise +cf_x_i_cont+ would resolve as key +x_i+ with predicate
      # +cont+. A key that itself ends in a predicate name (+..._eq_eq+) is
      # only reachable if the shorter split names a real definition.
      #
      # @param key [String, Symbol]
      # @return [Hash, nil] +{ definition:, predicate: }+
      def parse_filter(key)
        value = key.to_s
        return unless value.start_with?('cf_')

        ORDERED_FILTER_PREDICATES.each do |predicate|
          next unless value.end_with?("_#{predicate}")

          definition = entries[value.delete_suffix("_#{predicate}")]
          next unless definition && filter_predicates_for(definition.field_type).include?(predicate)

          return { definition: definition, predicate: predicate }
        end

        nil
      end

      # @param field_type [String]
      # @return [Array<String>]
      def filter_predicates_for(field_type)
        field_type == 'number' ? NUMBER_FILTER_PREDICATES : TEXT_FILTER_PREDICATES
      end

      # Stamp for Store API filters cache keys.
      #
      # @return [String]
      def schema_version
        @schema_version ||= [
          entries.size,
          entries.each_value.filter_map(&:updated_at).max&.utc&.iso8601(6)
        ].join('-')
      end

      private

      def product_definitions
        scope = Spree::CustomFieldDefinition.for_resource_type('Spree::Product')
        scope.where(searchable: true).or(scope.where(sortable: true))
      end

      def sort_option_label(name, field_type, direction)
        suffix =
          if field_type == 'number'
            direction == :asc ? Spree.t(:sort_low_to_high) : Spree.t(:sort_high_to_low)
          else
            direction == :asc ? Spree.t(:sort_a_to_z) : Spree.t(:sort_z_to_a)
          end
        "#{name} (#{suffix})"
      end
    end
  end
end
