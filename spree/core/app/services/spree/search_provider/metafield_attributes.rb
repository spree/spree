# frozen_string_literal: true

module Spree
  module SearchProvider
    # Cached registry + document helpers for searchable / sortable product metafields.
    # Used by SearchProvider (Database, Meilisearch) and ProductPresenter —
    class MetafieldAttributes
      CACHE_KEY = 'spree/search_provider/metafield_attributes/v2'

      class << self
        # @return [Hash] :by_key, :searchable_keys, :sortable_keys
        def registry
          Rails.cache.fetch(CACHE_KEY) { build_registry }
        end

        def clear_cache!
          Rails.cache.delete(CACHE_KEY)
        end

        # @return [Hash{String => Hash}]
        def build_registry
          product_defs = Spree::MetafieldDefinition.for_resource_type('Spree::Product')
          definitions = product_defs.where(searchable: true).or(product_defs.where(sortable: true))

          by_key = {}
          searchable_keys = []
          sortable_keys = []

          definitions.find_each do |definition|
            key = definition.search_key
            by_key[key] = {
              id: definition.id,
              name: definition.name,
              field_type: definition.field_type,
              searchable: definition.searchable?,
              sortable: definition.sortable?
            }
            searchable_keys << key if definition.searchable?
            sortable_keys << key if definition.sortable?
          end

          {
            by_key: by_key,
            searchable_keys: searchable_keys,
            sortable_keys: sortable_keys
          }
        end

        # @return [Array<String>]
        def searchable_attribute_keys
          registry[:searchable_keys]
        end

        # @return [Array<String>]
        def sortable_attribute_keys
          registry[:sortable_keys]
        end

        # @return [Array<String>]
        def sort_ids
          sortable_attribute_keys.flat_map { |key| [key, "-#{key}"] }
        end

        # Labeled sort options for Store API filters (id is the sort param).
        #
        # @return [Array<Hash>] +{ id:, label: }+
        def sort_options
          sortable_attribute_keys.flat_map do |key|
            entry = entry_for(key)
            name = entry[:name].presence || key
            [
              { id: key, label: sort_option_label(name, entry[:field_type], :asc) },
              { id: "-#{key}", label: sort_option_label(name, entry[:field_type], :desc) }
            ]
          end
        end

        # @param attribute_key [String]
        # @return [Hash, nil]
        def entry_for(attribute_key)
          registry[:by_key][attribute_key]
        end

        # @param sort [String, nil]
        # @return [Hash, nil] { attribute:, direction: 'asc'|'desc' }
        def parse_sort(sort)
          return nil if sort.blank?

          descending = sort.start_with?('-')
          attribute = descending ? sort[1..] : sort
          entry = entry_for(attribute)
          return nil unless entry&.fetch(:sortable)

          { attribute: attribute, direction: descending ? 'desc' : 'asc' }
        end

        # Flat mf_* hash for a product search document (searchable ∪ sortable).
        #
        # @param product [Spree::Product]
        # @return [Hash{String => Object}]
        def document_attributes(product)
          entries = registry[:by_key]
          return {} if entries.blank?

          by_definition_id = product.metafields.index_by(&:metafield_definition_id)

          entries.each_with_object({}) do |(attribute_key, entry), hash|
            next unless entry[:searchable] || entry[:sortable]

            metafield = by_definition_id[entry[:id]]
            next unless metafield

            hash[attribute_key] = index_value(metafield)
          end
        end

        # @param metafield [Spree::Metafield]
        # @return [Float, String]
        def index_value(metafield)
          serialized = metafield.serialize_value
          case metafield
          when Spree::Metafields::Number
            serialized.to_f
          else
            serialized.to_s
          end
        end

        # Database-agnostic type-cast expression for metafield sort values.
        # Adapts numeric values across PostgreSQL, MySQL, and SQLite dialects.
        # Used to project sort columns into SELECT so DISTINCT works with ORDER BY.
        #
        # @param field_type [String] API field type token (e.g. +number+)
        # @param adapter_name [String] ActiveRecord adapter name
        # @return [String] SQL expression (unaliased, unordered)
        def sort_expression_sql(field_type:, adapter_name:)
          column = 'sort_mf.value'
          return column unless field_type == 'number'

          case adapter_name
          when /PostgreSQL/i
            "#{column}::numeric"
          when /Mysql|Trilogy/i
            "CAST(#{column} AS DECIMAL(30, 10))"
          else
            "CAST(#{column} AS REAL)"
          end
        end

        # NULL-rank expression (0 for non-NULL, 1 for NULL) to sort missing
        # metafields last consistently across all adapters (Meilisearch parity).
        # Projected as +mf_sort_missing+ in apply_metafield_sort because
        # PostgreSQL rejects +(alias IS NULL)+ in ORDER BY clauses.
        #
        # @param field_type [String] API field type token
        # @param adapter_name [String] ActiveRecord adapter name
        # @return [String] SQL expression: (sort_expr IS NULL)
        def sort_null_rank_sql(field_type:, adapter_name:)
          expression = sort_expression_sql(field_type: field_type, adapter_name: adapter_name)
          "(#{expression} IS NULL)"
        end

        private

        # @param name [String] MetafieldDefinition display name
        # @param field_type [String]
        # @param direction [Symbol] +:asc+ or +:desc+
        # @return [String]
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
end
