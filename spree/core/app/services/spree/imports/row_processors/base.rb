module Spree
  module Imports
    module RowProcessors
      class Base
        def initialize(row, mappings: nil, schema_fields: nil)
          @row = row
          @import = row.import
          @attributes = if mappings && schema_fields
                          build_schema_hash(row, mappings, schema_fields)
                        else
                          row.to_schema_hash
                        end
        end

        attr_reader :row, :import, :attributes

        def process!
          raise NotImplementedError, 'Subclasses must implement the process! method'
        end

        private

        # Memoizes a shared-record lookup (including nil misses) in the import's
        # per-job cache so repeated rows don't re-run the same query.
        def cached_lookup(*key)
          cache = import.row_lookup_cache
          return cache[key] if cache.key?(key)

          cache[key] = yield
        end

        # Feeds name a variant by SKU or by the key their own system holds —
        # a warehouse export has no reason to know Spree's ids. Shared so
        # every feed processor agrees on the lookup, the default system and
        # the cache keys; diverging cache keys would silently halve the
        # import's hit rate.
        #
        # @return [Spree::Variant]
        # @raise [ArgumentError] when the row names nothing, or nothing matches
        def find_variant!
          sku = attributes['sku'].to_s.strip
          external_id = attributes['external_id'].to_s.strip
          raise ArgumentError, 'A SKU or external ID is required' if sku.blank? && external_id.blank?

          variant =
            if sku.present?
              cached_lookup(:variant_sku, sku) { store_variants.find_by(sku: sku) }
            else
              system = attributes['external_system'].to_s.strip.presence || 'erp'
              cached_lookup(:variant_external, system, external_id) do
                store_variants.find_by_external_id(system, external_id)
              end
            end

          raise ArgumentError, "No variant matches #{sku.presence || external_id}" if variant.nil?

          variant
        end

        def store_variants
          @store_variants ||= import.store.variants
        end

        def build_schema_hash(row, mappings, schema_fields)
          attributes = {}
          schema_fields.each do |field|
            mapping = mappings.find { |m| m.schema_field == field[:name] }
            next unless mapping&.mapped?

            attributes[field[:name]] = row.data_json[mapping.file_column]
          end
          attributes
        end
      end
    end
  end
end
