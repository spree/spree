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
      # Comparison ops for metric filters. A metric filter compiles to HAVING,
      # so it takes scalar comparisons rather than the set membership a
      # dimension filter uses.
      METRIC_FILTER_OPS = %w[eq gt gte lt lte].freeze
      COMPARE_MODES = %w[previous_period previous_year].freeze
      # Hourly buckets over a wide range produce a series nothing can read
      # (a year is 8,760 points), so the grain is refused rather than
      # silently coarsened (Decision 4).
      MAX_BUCKETS = 2_000
      LAST_N_RANGE = /\Alast_(\d+)_(days|weeks|months)\z/
      # Named presets, resolved in the store's timezone (see #time_zone).
      PRESETS = %w[today yesterday week_to_date month_to_date quarter_to_date year_to_date
                   last_week last_month last_quarter].freeze
      # The `last_<n>_<unit>` ranges worth a labelled entry in pickers; any
      # other count/unit pair is accepted through LAST_N_RANGE.
      RELATIVE_PRESETS = %w[last_7_days last_30_days last_4_weeks last_90_days last_12_months].freeze

      attr_reader :store, :registry, :currency, :metrics, :dimensions, :filters,
                  :metric_filters, :time_range, :compare, :sort, :limit

      def initialize(store:, params:, registry: Spree.reporting)
        @store = store
        @registry = registry
        raise InvalidQuery, 'query must be an object' unless params.respond_to?(:to_h)

        params = params.to_h.deep_symbolize_keys

        @currency = params[:currency].presence || store.default_currency
        @metrics = normalize_metrics(params[:metrics])
        @dimensions = normalize_dimensions(params[:dimensions])
        @filters = normalize_filters(params[:filters])
        @metric_filters = normalize_metric_filters(params[:metric_filters])
        @time_range = normalize_time_range(params[:time_range])
        @compare = normalize_compare(params[:compare])
        @sort = normalize_sort(params[:sort])
        @limit = normalize_limit(params[:limit])
        validate_bases!
        validate_include_empty_filters!
        validate_bucket_count!
        validate_lifetime_metrics!
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
        ([Spree::Order] + authorized_members.filter_map(&:subject).map(&:call)).uniq
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
        authorized_members.filter_map(&:key_scope).uniq
      end

      # Every member whose definition names an authorization subject: the
      # dimensions the query groups or filters by, and the metrics that expose
      # money living outside the order itself.
      # Aggregated rather than requested metrics, so a ratio built on a gated
      # component is gated too.
      def authorized_members
        referenced_dimensions + aggregated_metrics
      end

      def referenced_dimensions
        (dimensions.map { |d| d[:dimension] } + filters.map { |f| f[:dimension] }).uniq
      end

      # The period this query compares against.
      #
      # `previous_period` shifts by an equal number of calendar days in the
      # store zone, so a range spanning a DST change keeps its midnight edges.
      # `previous_year` shifts by a calendar year instead: "the same month last
      # year" means February to February, and an equal-day-count shift off a
      # 28-day February would land in January. ActiveSupport maps February 29
      # to February 28 in a non-leap year.
      def previous_time_range
        first = time_range.first.in_time_zone(time_zone)
        last = time_range.last.in_time_zone(time_zone)

        if compare == 'previous_year'
          (first - 1.year)..(last - 1.year)
        else
          days = (last.to_date - first.to_date).to_i + 1
          (first - days.days)..(last - days.days)
        end
      end

      def compare?
        compare.present?
      end

      # Whether a dimension's whole population leads the query, so members with
      # no matching rows still produce a row.
      def include_empty?
        dimensions.any? { |d| d[:include_empty] }
      end

      # All metrics the adapter must aggregate: requested non-derived metrics
      # plus the hidden components of requested ratios.
      def aggregated_metrics
        metrics.flat_map { |metric| registry.components(metric) }.uniq(&:name)
      end

      # The currency a base should filter by, or nil when the question does not
      # involve money.
      #
      # Amounts in different currencies are never converted or added, so a
      # money metric has to be scoped to one. A count or a quantity is not
      # money and carries no such constraint — restricting it anyway would
      # answer "how many orders did we take" with only the share that happened
      # to be priced in one currency, which is wrong rather than partial. A
      # ratio counts as money when either side is (average order value), and
      # not when neither is (sell-through).
      def scope_currency
        currency if aggregated_metrics.any?(&:money?)
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
          hash = entry.is_a?(Hash)
          name, grain = hash ? [entry[:name], entry[:grain]] : [entry, nil]
          dimension = registry.dimension!(member_name(name, 'dimension'))

          if dimension.time?
            grain = (grain || dimension.grains.first).to_sym
            unless dimension.grains.include?(grain)
              raise InvalidQuery, "invalid grain #{grain} for #{dimension.name}. Valid grains: #{dimension.grains.join(', ')}"
            end
          elsif grain.present?
            raise InvalidQuery, "dimension #{dimension.name} does not support grains"
          end

          { dimension: dimension, grain: grain, include_empty: hash && ActiveModel::Type::Boolean.new.cast(entry[:include_empty]).present? }
        end

        raise InvalidQuery, "at most #{MAX_DIMENSIONS} dimensions per query" if dims.size > MAX_DIMENSIONS
        raise InvalidQuery, 'at most one time dimension per query' if dims.count { |d| d[:dimension].time? } > 1

        validate_include_empty!(dims)
        dims
      end

      # `include_empty` roots the query in the dimension's own population so
      # members with no matching rows still appear (the "which products never
      # sold" question). It needs a relation to enumerate, and it only makes
      # sense as the sole grouping — a second dimension would multiply the
      # empty side into rows that never existed.
      def validate_include_empty!(dims)
        empty = dims.select { |d| d[:include_empty] }
        return if empty.empty?

        if dims.size > 1
          raise InvalidQuery, 'include_empty supports exactly one dimension'
        end

        dimension = empty.first[:dimension]
        unless dimension.population?
          raise InvalidQuery,
                "dimension #{dimension.name} does not support include_empty — it has no record list to draw empty rows from"
        end

      end

      # Metric filters are a separate contract key rather than an op inside
      # `filters` because they compile to HAVING: they run after aggregation,
      # cannot use the id-subquery path a joined dimension filter needs, and
      # never narrow the ungrouped totals.
      def normalize_metric_filters(list)
        raise InvalidQuery, 'metric_filters must be an array' unless list.nil? || list.is_a?(Array)

        Array(list).map do |filter|
          raise InvalidQuery, 'each metric filter must be an object with metric, op and value' unless filter.is_a?(Hash)

          metric = registry.metric!(member_name(filter[:metric], 'metric'))
          op = filter[:op].to_s
          unless METRIC_FILTER_OPS.include?(op)
            raise InvalidQuery, "invalid metric filter op #{op}. Valid ops: #{METRIC_FILTER_OPS.join(', ')}"
          end

          unless metrics.any? { |requested| requested.name == metric.name }
            raise InvalidQuery,
                  "metric_filters may only reference a requested metric; add #{metric.name} to metrics or filter on one of #{metrics.map(&:name).join(', ')}"
          end

          # A ratio is divided in Ruby after aggregation, so its value never
          # exists in SQL for HAVING to compare against.
          if metric.derived?
            raise InvalidQuery,
                  "#{metric.name} is a derived metric and cannot be filtered. Filter on one of its components instead: #{registry.components(metric).map(&:name).join(', ')}"
          end

          value = filter[:value]
          raise InvalidQuery, "metric filter on #{metric.name} requires a numeric value" unless numeric?(value)

          { metric: metric, op: op.to_sym, value: BigDecimal(value.to_s) }
        end
      end

      # The filter value is the one piece of request data that reaches the
      # statement as a number rather than a bound parameter, so anything that
      # is not finite is refused here: BigDecimal('Infinity') parses happily
      # and would render as the bare token `Infinity` in the HAVING clause.
      def numeric?(value)
        BigDecimal(value.to_s).finite?
      rescue ArgumentError, TypeError
        false
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
        return DEFAULT_VALUE_LIMIT if value.blank? && time_dimension.nil? && dimensions.any?
        return if value.blank?

        limit = Integer(value, exception: false)
        raise InvalidQuery, "limit must be an integer between 1 and #{MAX_LIMIT}" if limit.nil? || limit < 1

        limit.clamp(1, MAX_LIMIT)
      end

      # :orders-based metrics cannot be grouped or filtered by :line_items
      # dimensions (order totals per product/category would double count).
      #
      # The refusal names the reason and the way through: a caller who asked
      # for total sales per product wants net_sales, and learning that from
      # the error is the difference between a usable API and a wall. The agent
      # surface has nothing else to learn the vocabulary from.
      def validate_bases!
        validate_one_family!

        incompatible = referenced_dimensions.reject { |d| metrics.all? { |m| registry.compatible?(m, d) } }
        return if incompatible.empty?

        offenders = metrics.reject { |m| incompatible.all? { |d| registry.compatible?(m, d) } }
        raise InvalidQuery, incompatible_base_message(offenders, incompatible)
      end

      def incompatible_base_message(offenders, dimensions)
        names = offenders.map(&:name)
        message = "#{names.join(', ')} cannot be grouped by #{dimensions.map(&:name).join(', ')}: " \
                  'they measure money that belongs to the whole order (shipping, duties and tax included), ' \
                  'so splitting them per line would count the same money under several rows.'

        alternatives = offenders.filter_map(&:suggests).uniq
        return message if alternatives.empty?

        "#{message} Use #{alternatives.join(' or ')} for a per-line breakdown."
      end

      # Sales, payments and inventory answer different questions on different
      # clocks — a payment total beside a units-received count is two reports
      # wearing one table. The refusal names each metric's clock so a caller
      # can see why the two cannot share a row, and split the query.
      def validate_one_family!
        by_family = aggregated_metrics.group_by { |metric| registry.family_of(metric) }
        return if by_family.size <= 1

        described = by_family.sort_by { |family, _| family.to_s }.map do |family, family_metrics|
          clock = registry.base!(family_metrics.first.base).clock
          "#{family_metrics.map(&:name).join(', ')} measures #{family}" \
            "#{" (#{clock})" if clock.present?}"
        end

        raise InvalidQuery,
              "#{described.join(', while ')}. One query cannot report both — run them as separate queries."
      end

      # A filter on another dimension describes the facts, not the members, so
      # it cannot narrow the population "include_empty" draws from: "which
      # shoes never sold" filtered by category would list every unsold product
      # in the store. Refused rather than answered wrongly.
      def validate_include_empty_filters!
        entry = dimensions.find { |d| d[:include_empty] }
        return if entry.nil?

        name = entry[:dimension].name
        foreign = filters.map { |f| f[:dimension] }.reject { |d| d.name == name }.uniq
        return if foreign.empty?

        raise InvalidQuery,
              "include_empty on #{name} cannot be combined with a filter on " \
              "#{foreign.map(&:name).join(', ')} — that filter narrows what sold, not which " \
              "#{name}s exist. Filter on #{name} instead."
      end

      def validate_bucket_count!
        entry = time_dimension
        return if entry.nil?

        buckets = estimated_buckets(entry[:grain])
        return if buckets.nil? || buckets <= MAX_BUCKETS

        raise InvalidQuery,
              "#{entry[:grain]} grain over this range produces #{buckets} points (the limit is #{MAX_BUCKETS}). " \
              "Shorten the range or use a coarser grain: #{coarser_grains(entry).join(', ')}."
      end

      # Only the hour grain is capped here. Day and coarser grains are bounded
      # by the adapter's own MAX_RANGE_DAYS, and checking them here too would
      # answer "this range is absurdly long" with a message about grains.
      def estimated_buckets(grain)
        return unless grain == :hour

        ((time_range.last - time_range.first) / 1.hour).ceil
      end

      def coarser_grains(entry)
        available = entry[:dimension].grains
        available[(available.index(entry[:grain]).to_i + 1)..].presence || [available.last]
      end

      # A metric declaring `requires_grouping` covers more than the query's
      # time range (a customer's whole history), so ungrouped it would collapse
      # every group's figure into one number that answers no question. Which
      # dimension it needs is registry data, so an extension's own metric gets
      # the same refusal without touching the compiler.
      def validate_lifetime_metrics!
        aggregated_metrics.select(&:per_group?).group_by(&:requires_grouping).each do |needed, group|
          next if dimensions.any? { |d| d[:dimension].name == needed }

          raise InvalidQuery,
                "#{group.map(&:name).join(', ')} covers more than the report's date range, " \
                "so it must be grouped by #{needed}."
        end
      end

    end
  end
end
