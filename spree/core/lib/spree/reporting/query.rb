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
      LAST_N_RANGE = /\Alast_(\d+)_(days|weeks|months)\z/
      # Named presets, resolved in the store's timezone (see #time_zone).
      PRESETS = %w[today yesterday week_to_date month_to_date quarter_to_date year_to_date
                   last_week last_month last_quarter].freeze
      # The `last_<n>_<unit>` ranges worth a labelled entry in pickers; any
      # other count/unit pair is accepted through LAST_N_RANGE.
      RELATIVE_PRESETS = %w[last_7_days last_30_days last_4_weeks last_90_days last_12_months].freeze

      attr_reader :store, :registry, :currency, :metrics, :dimensions, :filters,
                  :time_range, :compare, :sort, :limit

      def initialize(store:, params:, registry: Spree.reporting)
        @store = store
        @registry = registry
        raise InvalidQuery, 'query must be an object' unless params.respond_to?(:to_h)

        params = params.to_h.deep_symbolize_keys

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

      # Day+ grains and relative ranges resolve in the store's timezone
      # (Decision 7); adapters read it from here so every consumer agrees.
      def time_zone
        @time_zone ||= Time.find_zone(store.preferred_timezone) || Time.zone
      end

      # Authorization subjects for this query: order data (the floor for all
      # reporting) plus every referenced member's declared subject. Every
      # consumer — API controller, saved reports, agent tools — must ensure
      # `:read` on each before executing.
      def required_subjects
        ([Spree::Order] + referenced_dimensions.filter_map(&:subject).map(&:call)).uniq
      end

      # The subjects a given ability may not read — empty when the query is
      # fully authorized. The one rule every consumer (API, exports, agent
      # tools) applies, so member-level authorization cannot drift.
      #
      # @param ability [CanCan::Ability]
      # @return [Array<Class, Symbol>]
      def unreadable_subjects(ability)
        required_subjects.reject { |subject| ability.can?(:read, subject) }
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

      # The immediately preceding period of equal length, shifted by calendar
      # days in the store zone so a range that spans a DST change keeps its
      # midnight edges instead of drifting by an hour.
      def previous_time_range
        first = time_range.first.in_time_zone(time_zone)
        last = time_range.last.in_time_zone(time_zone)
        days = (last.to_date - first.to_date).to_i + 1
        (first - days.days)..(last - days.days)
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
        raise InvalidQuery, 'metrics must be a non-empty array of metric names' unless names.is_a?(Array) && names.any?

        names.map { |name| registry.metric!(member_name(name, 'metric')) }
      end

      # Member references are plain strings; anything else is a malformed
      # contract, not an unknown member.
      def member_name(value, kind)
        raise InvalidQuery, "#{kind} names must be strings" unless value.is_a?(String) || value.is_a?(Symbol)

        value
      end

      def normalize_dimensions(list)
        raise InvalidQuery, 'dimensions must be an array' unless list.nil? || list.is_a?(Array)

        dims = Array(list).map do |entry|
          name, grain = entry.is_a?(Hash) ? [entry[:name], entry[:grain]] : [entry, nil]
          dimension = registry.dimension!(member_name(name, 'dimension'))

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
        raise InvalidQuery, 'filters must be an array' unless list.nil? || list.is_a?(Array)

        Array(list).map do |filter|
          raise InvalidQuery, 'each filter must be an object with dimension, op and value' unless filter.is_a?(Hash)

          dimension = registry.dimension!(member_name(filter[:dimension], 'dimension'))
          op = filter[:op].to_s
          raise InvalidQuery, "invalid filter op #{op}. Valid ops: #{FILTER_OPS.join(', ')}" unless FILTER_OPS.include?(op)
          raise InvalidQuery, "filter on #{dimension.name} requires a value" if filter[:value].blank?

          { dimension: dimension, op: op.to_sym, values: Array(filter[:value]) }
        end
      end

      def resolve_filter_value(dimension, value)
        dimension.resolve ? dimension.resolve.call(store, value) : value
      end

      # Accepts `{ preset: "last_month" }` (named or `last_<n>_<unit>`) or
      # `{ since:, until: }` with ISO 8601 dates/datetimes.
      # Everything resolves in the store's timezone so "yesterday" means the
      # merchant's yesterday.
      def normalize_time_range(range)
        range ||= {}
        raise InvalidQuery, 'time_range must be an object' unless range.is_a?(Hash)
        return preset_range(range[:preset]) if range[:preset].present?

        from = parse_time(range[:since], edge: :begin) || 30.days.ago.in_time_zone(time_zone).beginning_of_day
        to = parse_time(range[:until], edge: :end) || Time.current.in_time_zone(time_zone).end_of_day
        raise InvalidQuery, 'time_range.since must precede time_range.until' if from > to

        from..to
      end

      def preset_range(name)
        now = Time.current.in_time_zone(time_zone)
        case name.to_s
        when 'today' then now.beginning_of_day..now.end_of_day
        when 'yesterday' then (now - 1.day).beginning_of_day..(now - 1.day).end_of_day
        when 'week_to_date' then now.beginning_of_week..now.end_of_day
        when 'month_to_date' then now.beginning_of_month..now.end_of_day
        when 'quarter_to_date' then now.beginning_of_quarter..now.end_of_day
        when 'year_to_date' then now.beginning_of_year..now.end_of_day
        when 'last_week' then (now - 1.week).beginning_of_week..(now - 1.week).end_of_week
        when 'last_month' then (now - 1.month).beginning_of_month..(now - 1.month).end_of_month
        when 'last_quarter' then (now - 3.months).beginning_of_quarter..(now - 3.months).end_of_quarter
        else
          if (match = LAST_N_RANGE.match(name.to_s))
            count, unit = match[1].to_i, match[2]
            (now - count.public_send(unit)).beginning_of_day..now.end_of_day
          else
            raise InvalidQuery, "invalid time_range preset #{name}. Valid presets: #{PRESETS.join(', ')}, last_<n>_<days|weeks|months>"
          end
        end
      end

      def parse_time(value, edge:)
        return if value.blank?

        # `iso8601`, never `parse`: parse fills in whatever a value omits, so
        # "09:00" would become today at nine and a saved window would move
        # every midnight. A bare date covers the whole day on either edge.
        time = time_zone.iso8601(value.to_s)
        if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          edge == :begin ? time.beginning_of_day : time.end_of_day
        else
          time
        end
      rescue ArgumentError, TypeError, KeyError
        raise InvalidQuery, "invalid time: #{value} (expected an ISO 8601 date or datetime)"
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
        incompatible = referenced_dimensions.reject { |d| metrics.all? { |m| registry.compatible?(m, d) } }
        return if incompatible.empty?

        offenders = metrics.reject { |m| incompatible.all? { |d| registry.compatible?(m, d) } }
        raise InvalidQuery,
              "metrics #{offenders.map(&:name).join(', ')} cannot be grouped by #{incompatible.map(&:name).join(', ')}"
      end
    end
  end
end
