module Spree
  module Reporting
    # The self-describing contract for one caller: labels and descriptions
    # (localized), metric formats with the store currency, per-dimension
    # metric compatibility, filter ops and enumerated values, the time-range
    # grammar, and store meta — filtered to the members the caller may
    # reference, so pickers never offer and agents never propose a member that
    # would be refused. Drives `GET /reporting/schema` and the agent tool schema.
    class Schema
      # @param store [Spree::Store]
      # @param registry [Registry]
      # @param allowed [Proc] ->(Dimension) { true/false } — permission gate
      def initialize(store:, registry: Spree.reporting, allowed: ->(_dimension) { true })
        @store = store
        @registry = registry
        @allowed = allowed
      end

      def to_h
        dimensions = @registry.dimensions.values.select { |d| @allowed.call(d) }
        {
          meta: {
            currency: @store.default_currency,
            timezone: (Time.find_zone(@store.preferred_timezone) || Time.zone).name,
            supported_currencies: @store.supported_currencies_list.map(&:iso_code)
          },
          metrics: @registry.metrics.values.map { |m| metric_entry(m) },
          dimensions: dimensions.map { |d| dimension_entry(d) },
          time_range: {
            presets: (Query::PRESETS + Query::RELATIVE_PRESETS).map { |p| { name: p, label: translate('presets', p, :label) } },
            relative: %w[last_<n>_days last_<n>_weeks last_<n>_months],
            absolute: 'ISO 8601 dates or datetimes in `since` / `until`, resolved in the store timezone'
          },
          # Ranking defaults the compiler applies, published so a client never
          # has to mirror them.
          limits: { default: Query::DEFAULT_VALUE_LIMIT, max: Query::MAX_LIMIT }
        }
      end

      # @param group [Symbol] :metrics | :dimensions
      # @return [String] localized label (humanized name when none registered)
      def label_for(group, name)
        translate(group, name, :label)
      end

      private

      def metric_entry(metric)
        {
          name: metric.name,
          label: translate('metrics', metric.name, :label),
          description: translate('metrics', metric.name, :description),
          format: metric.format,
          currency: (metric.money? ? @store.default_currency : nil),
          derived: metric.derived?
        }.compact
      end

      def dimension_entry(dimension)
        {
          name: dimension.name,
          label: translate('dimensions', dimension.name, :label),
          description: translate('dimensions', dimension.name, :description),
          type: dimension.type,
          grains: dimension.grains,
          lookup: dimension.lookup,
          filter_ops: Query::FILTER_OPS,
          values: dimension.enumerated_values&.map { |value| { name: value, label: self.class.value_label(dimension, value) } },
          # Order-level metrics cannot be broken down by line-item dimensions
          # (they would double count) — the compiler enforces the same rule.
          compatible_metrics: @registry.metrics.values.select { |m| @registry.compatible?(m, dimension) }.map(&:name)
        }.compact
      end

      def translate(group, name, facet)
        Spree.t("reporting.#{group}.#{name}.#{facet}", default: (facet == :label ? name.to_s.humanize : nil))
      end


      # Enumerated values are labelled server-side so a plugin dimension
      # declaring `values:` needs no dashboard locale edit; the schema, the
      # result hydration and the CSV export all read the same label.
      #
      # @param dimension [Registry::Dimension]
      # @param value [String]
      # @return [String]
      def self.value_label(dimension, value)
        Spree.t("reporting.values.#{dimension.name}.#{value}", default: value.to_s.humanize)
      end
    end
  end
end
