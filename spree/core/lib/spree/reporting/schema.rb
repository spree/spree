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
      # @param allowed [Proc] ->(member) { true/false } — permission gate,
      #   asked about metrics and dimensions alike
      def initialize(store:, registry: Spree.reporting, allowed: ->(_member) { true })
        @store = store
        @registry = registry
        @allowed = allowed
      end

      def to_h
        metrics = @registry.metrics.values.select { |m| @allowed.call(m) }
        dimensions = @registry.dimensions.values.select { |d| @allowed.call(d) }
        {
          meta: {
            currency: @store.default_currency,
            timezone: (Time.find_zone(@store.preferred_timezone) || Time.zone).name,
            supported_currencies: @store.supported_currencies_list.map(&:iso_code)
          },
          # Published so a builder can group the pickers and never offer a
          # cross-family pair the query would refuse.
          families: families(metrics),
          metrics: metrics.map { |m| metric_entry(m) },
          dimensions: dimensions.map { |d| dimension_entry(d, metrics) },
          time_range: {
            presets: (Query::PRESETS + Query::RELATIVE_PRESETS).map { |p| { name: p, label: translate('presets', p, :label) } },
            relative: %w[last_<n>_days last_<n>_weeks last_<n>_months],
            absolute: 'ISO 8601 dates or datetimes in `since` / `until`, resolved in the store timezone'
          },
          # Ranking defaults the compiler applies, published so a client never
          # has to mirror them.
          limits: { default: Query::DEFAULT_VALUE_LIMIT, max: Query::MAX_LIMIT,
                    max_buckets: Query::MAX_BUCKETS },
          # Filtering on an aggregate (HAVING) is a separate contract key from
          # `filters`, which narrow on dimensions before aggregation.
          metric_filter_ops: Query::METRIC_FILTER_OPS,
          compare_modes: Query::COMPARE_MODES
        }
      end

      # @param group [Symbol] :metrics | :dimensions
      # @return [String] localized label (humanized name when none registered)
      def label_for(group, name)
        translate(group, name, :label)
      end

      private

      # Each family with the members that belong to it, so a client can present
      # sales, payments and inventory as the separate reports they are.
      def families(metrics)
        metrics.group_by { |metric| @registry.family_of(metric) }.map do |family, family_metrics|
          {
            name: family,
            label: translate('families', family, :label),
            metrics: family_metrics.map(&:name),
            dimensions: @registry.dimensions.values.
              select { |d| @allowed.call(d) && @registry.base!(d.base).family == family }.map(&:name)
          }
        end
      end

      def metric_entry(metric)
        {
          name: metric.name,
          family: @registry.family_of(metric),
          label: translate('metrics', metric.name, :label),
          description: translate('metrics', metric.name, :description),
          format: metric.format,
          currency: (metric.money? ? @store.default_currency : nil),
          derived: metric.derived?,
          # A ratio is divided after aggregation, so it can be neither sorted
          # nor filtered in SQL. Published so a builder disables those controls
          # rather than letting a merchant discover it through a 422.
          filterable: !metric.derived?
        }.compact
      end

      def dimension_entry(dimension, metrics)
        {
          name: dimension.name,
          label: translate('dimensions', dimension.name, :label),
          description: translate('dimensions', dimension.name, :description),
          type: dimension.type,
          grains: dimension.grains,
          lookup: dimension.lookup,
          filter_ops: Query::FILTER_OPS,
          # Whether this dimension can lead a query with include_empty, which
          # is what answers "which of these never had any activity".
          supports_include_empty: dimension.population?,
          values: dimension.enumerated_values&.map { |value| { name: value, label: self.class.value_label(dimension, value) } },
          # Order-level metrics cannot be broken down by line-item dimensions
          # (they would double count) — the compiler enforces the same rule.
          compatible_metrics: metrics.select { |m| @registry.compatible?(m, dimension) }.map(&:name)
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
