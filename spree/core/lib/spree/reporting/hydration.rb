module Spree
  module Reporting
    # Turns a result's raw group keys into display payloads through each
    # dimension's registered `hydrate` lambda, batched once per dimension
    # across every row. Shared by the API serializer and the CSV export so a
    # report reads the same on screen and in a file.
    class Hydration
      attr_reader :result, :store, :params, :registry

      def initialize(result, store:, params: {}, registry: Spree.reporting)
        @result = result
        @store = store
        @params = params
        @registry = registry
      end

      # @param name [String, Symbol] dimension name
      # @param raw [Object] the group key as aggregated
      # @return [Hash, Object] `{ id:, label:, meta: }` for hydrated dimensions, the raw key otherwise
      def value(name, raw)
        dimension = definition(name)
        # A row whose key is NULL is a real group — an order with no market or
        # channel — and needs a name a person can read, not a blank cell.
        return { id: nil, label: Spree.t('reporting.unassigned'), meta: {} } if raw.nil? && !plain?(dimension)
        return { id: raw.to_s, label: Schema.value_label(dimension, raw), meta: {} } if dimension.enumerated_values
        return raw unless dimension.hydrate

        hydrated[name.to_sym][raw] || { id: nil, label: raw.to_s, meta: {} }
      end

      # @return [String] what a person should read for this key
      def label(name, raw)
        value = value(name, raw)
        value.is_a?(Hash) ? value[:label].to_s : value.to_s
      end

      private

      # A dimension the wire carries as a bare value (a status, a country code)
      # rather than a { id, label, meta } payload.
      def plain?(dimension)
        dimension.enumerated_values.nil? && dimension.hydrate.nil?
      end

      def definition(name)
        @definitions ||= Hash.new { |cache, key| cache[key] = registry.dimension!(key) }
        @definitions[name.to_sym]
      end

      def hydrated
        @hydrated ||= begin
          keys = Hash.new { |hash, key| hash[key] = [] }
          result.rows.each do |row|
            row[:dimensions].each do |name, raw|
              keys[name.to_sym] << raw if definition(name).hydrate
            end
          end

          keys.to_h { |name, raws| [name, definition(name).hydrate.call(store, raws.uniq, params)] }
        end
      end
    end
  end
end
