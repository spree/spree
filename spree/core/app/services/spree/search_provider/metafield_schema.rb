# frozen_string_literal: true

module Spree
  module SearchProvider
    # Product metafield definitions that participate in search/sort.
    class MetafieldSchema
      # @return [Hash{String => Spree::MetafieldDefinition}]
      def entries
        @entries ||= product_definitions.index_by(&:search_key)
      end

      # @return [Array<String>]
      def searchable_attribute_keys
        @searchable_attribute_keys ||= entries.each_value.filter_map do |definition|
          definition.search_key if definition.searchable?
        end
      end

      # @return [Array<String>]
      def sortable_attribute_keys
        @sortable_attribute_keys ||= entries.each_value.filter_map do |definition|
          definition.search_key if definition.sortable?
        end
      end

      # @param attribute_key [String]
      # @return [Spree::MetafieldDefinition, nil]
      def entry_for(attribute_key)
        entries[attribute_key.to_s]
      end

      # @return [Array<String>]
      def sort_ids
        @sort_ids ||= sortable_attribute_keys.flat_map { |key| [key, "-#{key}"] }
      end

      # @return [Array<Hash>] +{ id:, label: }+
      def sort_options
        @sort_options ||= entries.each_value.select(&:sortable?).flat_map do |definition|
          key = definition.search_key
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
        scope = Spree::MetafieldDefinition.for_resource_type('Spree::Product')
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
