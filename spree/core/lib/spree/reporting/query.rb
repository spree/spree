module Spree
  module Reporting
    # Validates a contract query against the registry, normalizes it into an
    # execution plan (resolved members, time ranges, forced store/currency
    # scopes, resolved filter values), and runs it through a storage adapter.
    #
    # Raises UnknownMember / InvalidQuery for anything outside the registry —
    # unknown members are rejected, never silently dropped.
    class Query
      MAX_LIMIT = 1000
      DEFAULT_VALUE_LIMIT = 50
      MAX_DIMENSIONS = 2
      FILTER_OPS = %w[eq in].freeze
      COMPARE_MODES = %w[previous_period].freeze
      RELATIVE_RANGE = /\A-(\d+)d\z/

      attr_reader :store, :registry, :currency, :metrics, :dimensions, :filters,
                  :time_range, :compare, :sort, :limit

      def initialize(store:, params:, registry: Spree.reporting)
        @store = store
        @registry = registry
        params = params.deep_symbolize_keys

        @currency = params[:currency].presence || store.default_currency
        @metrics = normalize_metrics(params[:metrics])
        @dimensions = normalize_dimensions(params[:dimensions])
        @filters = normalize_filters(params[:filters])
        @time_range = normalize_time_range(params[:time_range])
        @compare = normalize_compare(params[:compare])
        @sort = normalize_sort(params[:sort])
        @limit = normalize_limit(params[:limit])
        validate_bases!
      end

      def execute(adapter: Spree::Dependencies.reporting_adapter.constantize.new)
        resolve_filter_values!
        adapter.execute(self)
      end

      # Filter values resolve lazily (prefixed ids → store-scoped record ids)
      # so authorization can run between construction and execution — a
      # forbidden member must 403 before an unknown id can 404.
      def resolve_filter_values!
        return if @filter_values_resolved

        filters.each do |filter|
          filter[:values] = filter[:values].map { |value| resolve_filter_value(filter[:dimension], value) }
        end
        @filter_values_resolved = true
      end

      def time_dimension
        dimensions.find { |d| d[:dimension].time? }
      end

      # Authorization subjects for this query: order data (the floor for all
      # reporting) plus every referenced member's declared subject. Every
      # consumer — API controller, saved reports, agent tools — must ensure
      # `:read` on each before executing.
      def required_subjects
        ([Spree::Order] + referenced_dimensions.filter_map(&:subject).map(&:call)).uniq
      end

      # API-key scopes required beyond `read_reports` (which gates the
      # endpoint and covers the order-data floor): the `key_scope` of every
      # referenced member with an authorization subject.
      def required_key_scopes
        referenced_dimensions.filter_map(&:key_scope).uniq
      end

      def referenced_dimensions
        (dimensions.map { |d| d[:dimension] } + filters.map { |f| f[:dimension] }).uniq
      end

      # The immediately preceding period of equal length.
      def previous_time_range
        duration = time_range.last - time_range.first
        (time_range.first - duration)..(time_range.last - duration)
      end

      def compare?
        compare.present?
      end

      # All metrics the adapter must aggregate: requested non-derived metrics
      # plus the hidden components of requested ratios.
      def aggregated_metrics
        base = metrics.reject(&:derived?)
        components = metrics.select(&:derived?).flat_map { |m| m.ratio.map { |name| registry.metric!(name) } }
        (base + components).uniq(&:name)
      end

      private

      def normalize_metrics(names)
        raise InvalidQuery, 'metrics must be a non-empty array' if names.blank?

        Array(names).map { |name| registry.metric!(name) }
      end

      def normalize_dimensions(list)
        dims = Array(list).map do |entry|
          name, grain = entry.is_a?(Hash) ? [entry[:name], entry[:grain]] : [entry, nil]
          dimension = registry.dimension!(name)

          if dimension.time?
            grain = (grain || dimension.grains.first).to_sym
            unless dimension.grains.include?(grain)
              raise InvalidQuery, "invalid grain #{grain} for #{dimension.name}. Valid grains: #{dimension.grains.join(', ')}"
            end
          elsif grain.present?
            raise InvalidQuery, "dimension #{dimension.name} does not support grains"
          end

          { dimension: dimension, grain: grain }
        end

        raise InvalidQuery, "at most #{MAX_DIMENSIONS} dimensions per query" if dims.size > MAX_DIMENSIONS
        raise InvalidQuery, 'at most one time dimension per query' if dims.count { |d| d[:dimension].time? } > 1

        dims
      end

      def normalize_filters(list)
        Array(list).map do |filter|
          dimension = registry.dimension!(filter[:dimension])
          op = filter[:op].to_s
          raise InvalidQuery, "invalid filter op #{op}. Valid ops: #{FILTER_OPS.join(', ')}" unless FILTER_OPS.include?(op)
          raise InvalidQuery, "filter on #{dimension.name} requires a value" if filter[:value].blank?

          { dimension: dimension, op: op.to_sym, values: Array(filter[:value]) }
        end
      end

      def resolve_filter_value(dimension, value)
        dimension.resolve ? dimension.resolve.call(store, value) : value
      end

      def normalize_time_range(range)
        range ||= {}
        from = parse_time(range[:since], edge: :begin) || 30.days.ago.beginning_of_day
        to = parse_time(range[:until], edge: :end) || Time.current.end_of_day
        raise InvalidQuery, 'time_range.since must precede time_range.until' if from > to

        from..to
      end

      def parse_time(value, edge:)
        return if value.blank?

        if (match = RELATIVE_RANGE.match(value.to_s))
          return match[1].to_i.days.ago.beginning_of_day
        end

        time = Time.zone.parse(value.to_s) || raise(InvalidQuery, "invalid time: #{value}")
        # Date-only inputs cover the whole day on either edge.
        if value.to_s !~ /\d:\d/
          edge == :begin ? time.beginning_of_day : time.end_of_day
        else
          time
        end
      rescue ArgumentError
        raise InvalidQuery, "invalid time: #{value}"
      end

      def normalize_compare(value)
        return if value.blank?
        raise InvalidQuery, "invalid compare mode #{value}. Valid modes: #{COMPARE_MODES.join(', ')}" unless COMPARE_MODES.include?(value.to_s)

        value.to_s
      end

      def normalize_sort(value)
        return if value.blank?

        descending = value.to_s.start_with?('-')
        name = value.to_s.delete_prefix('-')
        raise InvalidQuery, "sort metric #{name} must be requested in metrics" unless metrics.any? { |m| m.name.to_s == name }

        { metric: name.to_sym, direction: descending ? :desc : :asc }
      end

      def normalize_limit(value)
        return value.to_i.clamp(1, MAX_LIMIT) if value.present?

        DEFAULT_VALUE_LIMIT if time_dimension.nil? && dimensions.any?
      end

      # :orders-based metrics cannot be grouped or filtered by :line_items
      # dimensions (order totals per product/category would double count).
      def validate_bases!
        line_item_dims = (dimensions.map { |d| d[:dimension] } + filters.map { |f| f[:dimension] })
          .select { |d| d.base == :line_items }.uniq
        return if line_item_dims.empty?

        offenders = aggregated_metrics.select { |m| m.base == :orders }
        return if offenders.empty?

        raise InvalidQuery,
              "metrics #{offenders.map(&:name).join(', ')} cannot be grouped by #{line_item_dims.map(&:name).join(', ')}"
      end
    end
  end
end
