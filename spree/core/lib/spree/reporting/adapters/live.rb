module Spree
  module Reporting
    module Adapters
      # Compiles reporting queries straight against the transactional schema
      # through store-scoped associations. Default adapter — zero extra infra.
      #
      # Metrics aggregate on their own base relation (:orders or :line_items);
      # one grouped SQL query runs per base per period and the row sets merge
      # on dimension keys. Time buckets resolve in the store's timezone and
      # zero-fill across the requested range. Ranked value-dimension queries
      # push ORDER BY/LIMIT into SQL, and their comparison period only
      # aggregates the surviving keys.
      class Live < Base
        def execute(query)
          @query = query

          current = period_data(query.time_range, push_sort: sql_sortable?)
          previous = query.compare? ? period_data(query.previous_time_range, key_filter: compare_key_filter(current)) : nil

          Result.new(
            meta: {
              currency: query.currency,
              time_range: query.time_range,
              previous_time_range: query.compare? ? query.previous_time_range : nil,
              metrics: query.metrics.map(&:name),
              dimensions: query.dimensions.map { |d| { name: d[:dimension].name, grain: d[:grain] }.compact }
            },
            totals: build_totals(current, previous),
            rows: build_rows(current, previous)
          )
        end

        private

        # ---- period execution ----

        def period_data(range, push_sort: false, key_filter: nil)
          {
            range: range,
            totals: aggregate(range, grouped: false),
            groups: query.dimensions.any? ? aggregate(range, grouped: true, push_sort: push_sort, key_filter: key_filter) : {}
          }
        end

        # Runs one SQL query per metric base; returns { key_tuple => { metric => value } }.
        # Ungrouped aggregates use the single [] key.
        def aggregate(range, grouped:, push_sort: false, key_filter: nil)
          rows = Hash.new { |h, k| h[k] = {} }

          query.aggregated_metrics.group_by(&:base).each do |base, metrics|
            scope = base_scope(base, range, grouped: grouped)
            selects = metrics.map { |m| "#{resolve_sql(m.sql)} AS #{metric_alias(m)}" }

            if grouped
              dimension_selects = query.dimensions.map do |d|
                "#{dimension_expression(d)} AS #{dimension_alias(d)}"
              end
              scope = scope.group(query.dimensions.map { |d| Arel.sql(dimension_expression(d)) })
              scope = apply_key_filter(scope, key_filter) if key_filter
              scope = apply_sql_sort(scope, metrics) if push_sort
              selects = dimension_selects + selects
            end

            connection.select_all(scope.select(selects.map { |s| Arel.sql(s) }).to_sql).each do |row|
              key = grouped ? query.dimensions.map { |d| dimension_key(d, row[dimension_alias(d)]) } : []
              metrics.each { |m| rows[key][m.name] = cast_value(m, row[metric_alias(m)]) }
            end
          end

          rows.each_value { |metrics| apply_derived(metrics) }
          rows
        end

        # The grouped query carries the dimension joins; the ungrouped totals
        # deliberately do not — a join that is not 1:1 with the base rows (a
        # product in three categories, an order without a shipping address)
        # would otherwise multiply or drop rows, and the Total row must equal
        # the dimensionless figure for the same range and filters.
        def base_scope(base, range, grouped:)
          scope = base_relation(base, range)
          scope = apply_dimension_joins(scope, base) if grouped
          apply_filters(scope, base, range)
        end

        # The completed_at range predicate implies completeness, so neither
        # base needs the `complete` scope on top (merging it would replace the
        # range condition — Rails merge overwrites same-column wheres). A
        # canceled order keeps its completed_at, so it is excluded explicitly:
        # sales figures count what stayed sold.
        def base_relation(base, range)
          order_conditions = { currency: query.currency, completed_at: range }
          scope = case base
                  when :orders
                    query.store.orders.not_canceled.where(order_conditions)
                  when :line_items
                    query.store.line_items.merge(Spree::Order.not_canceled)
                      .where(Spree::Order.table_name => order_conditions)
                  else
                    raise InvalidQuery, "unknown metric base #{base}"
                  end

          # Association default orderings break grouped selects on PostgreSQL.
          scope.reorder(nil)
        end

        # Dimension joins are declared from their own base; they only apply
        # when the executing scope is that base (an :orders-based metric never
        # joins line-item tables — validate_bases! guarantees compatibility).
        def apply_dimension_joins(scope, base)
          query.dimensions.each do |d|
            scope = join_for(scope, d[:dimension], base)
          end
          scope
        end

        # A filter on a joined dimension narrows through an id subquery rather
        # than joining the aggregating scope itself: `category IN (a, b)` must
        # keep a line item once even when its product sits in both categories.
        def apply_filters(scope, base, range)
          query.filters.each do |filter|
            dimension = filter[:dimension]
            predicate = in_predicate(qualified_column(dimension), filter[:values])

            if dimension.joins.blank?
              scope = scope.where(predicate)
            else
              # Bounded like the outer query (store, currency, range) so the
              # planner starts from the same indexed slice.
              table = scope.klass.arel_table
              ids = join_for(base_relation(base, range), dimension, base).where(predicate).select(table[:id])
              scope = scope.where(table[:id].in(ids.arel))
            end
          end
          scope
        end

        # `column IN (values)` as an Arel node. The column is a validated
        # identifier (see #qualified_column) and the values bind as parameters,
        # so no request data reaches the statement as text.
        def in_predicate(column, values)
          Arel::Nodes::SqlLiteral.new(column).in(values)
        end

        # Dimension joins are declared from the dimension's own base. Reaching
        # an :orders dimension (e.g. the ship address) from the :line_items
        # base goes through the order association.
        def join_for(scope, dimension, base)
          return scope if dimension.joins.blank?
          return scope.joins(dimension.joins) if dimension.base == base
          return scope.joins(order: dimension.joins) if base == :line_items && dimension.base == :orders

          scope
        end

        # ---- sorted/limited rankings ----

        # ORDER BY + LIMIT can move into SQL when one base group carries every
        # aggregated metric (so the sort metric and the limit apply to the
        # same query) and the grouping is by value, not time buckets.
        def sql_sortable?
          return @sql_sortable unless @sql_sortable.nil?

          @sql_sortable = query.sort && query.limit && query.time_dimension.nil? && query.dimensions.any? &&
            !sort_metric.derived? && query.aggregated_metrics.map(&:base).uniq.one? || false
        end

        def sort_metric
          @sort_metric ||= query.registry.metric!(query.sort[:metric])
        end

        def apply_sql_sort(scope, metrics)
          return scope unless metrics.any? { |m| m.name == sort_metric.name }

          scope.order(Arel.sql("#{resolve_sql(sort_metric.sql)} #{query.sort[:direction] == :desc ? 'DESC' : 'ASC'}"))
            .limit(query.limit)
        end

        # The comparison period of a ranked value-dimension query only needs
        # the keys that made the current ranking — not every group in the
        # store's history. Only kicks in when SQL limited the current period,
        # so the IN clause is never larger than the limit.
        def compare_key_filter(current)
          return unless sql_sortable? && query.dimensions.size == 1

          keys = current[:groups].keys.flatten
          keys if keys.any?
        end

        def apply_key_filter(scope, keys)
          scope.where(in_predicate(dimension_expression(query.dimensions.first), keys))
        end

        # ---- SQL expressions ----

        def metric_alias(metric)
          "m_#{metric.name}"
        end

        # Registered fragments defer table names as %{placeholders} because
        # model classes cannot load while initializers register the vocabulary.
        def resolve_sql(fragment)
          format(fragment,
                 orders: Spree::Order.table_name,
                 line_items: Spree::LineItem.table_name,
                 variants: Spree::Variant.table_name,
                 products: Spree::Product.table_name,
                 addresses: Spree::Address.table_name,
                 product_categories: Spree::ProductCategory.table_name)
        end

        def dimension_alias(dim)
          "d_#{dim[:dimension].name}"
        end

        def dimension_expression(dim)
          dimension = dim[:dimension]
          return time_bucket_sql(qualified_column(dimension), dim[:grain]) if dimension.time?

          qualified_column(dimension)
        end

        # A registered dimension's column, as a SQL identifier. Registered
        # vocabulary is developer-authored, never request data, but this is
        # the point where it becomes SQL — so the resolved fragment must look
        # like `table.column` and nothing else. Anything richer is a
        # registration bug and raises rather than reaching the database.
        def qualified_column(dimension)
          resolved = if dimension.column.is_a?(String)
                       resolve_sql(dimension.column)
                     else
                       table = dimension.base == :orders ? Spree::Order.table_name : Spree::LineItem.table_name
                       "#{table}.#{dimension.column}"
                     end

          identifier!(resolved, dimension.name)
        end

        IDENTIFIER = /\A[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)?\z/i

        def identifier!(fragment, name)
          return fragment if IDENTIFIER.match?(fragment)

          raise InvalidQuery, "dimension #{name} resolved to an unusable column expression"
        end

        # Time buckets come back as Date on PostgreSQL and String elsewhere —
        # normalize to ISO strings so keys merge and zero-fill consistently.
        def dimension_key(dim, raw)
          dim[:dimension].time? ? raw.to_s : raw
        end

        # Store-timezone day/month buckets, per database. PostgreSQL converts
        # properly (DST-aware); SQLite/MySQL shift by the timezone's current
        # UTC offset — a documented approximation near DST boundaries.
        def time_bucket_sql(column, grain)
          case connection.adapter_name
          when /postgres/i
            local = "#{column} AT TIME ZONE 'UTC' AT TIME ZONE '#{query.time_zone.tzinfo.identifier}'"
            case grain
            when :day then "(#{local})::date"
            when :week then "date_trunc('week', #{local})::date"
            when :month then "date_trunc('month', #{local})::date"
            end
          when /mysql/i
            local = "CONVERT_TZ(#{column}, '+00:00', '#{format_offset(utc_offset)}')"
            case grain
            when :day then "DATE(#{local})"
            when :week then "DATE(DATE_SUB(#{local}, INTERVAL WEEKDAY(#{local}) DAY))"
            when :month then "DATE_FORMAT(#{local}, '%Y-%m-01')"
            end
          else # SQLite — weeks start on Monday (ISO), matching the other adapters
            case grain
            when :day then "DATE(#{column}, '#{utc_offset} seconds')"
            when :week then "DATE(#{column}, '#{utc_offset} seconds', '+1 day', 'weekday 1', '-7 days')"
            when :month then "strftime('%Y-%m-01', #{column}, '#{utc_offset} seconds')"
            end
          end
        end


        def utc_offset
          @utc_offset ||= query.time_zone.now.utc_offset
        end

        def format_offset(seconds)
          sign = seconds.negative? ? '-' : '+'
          format("#{sign}%02d:%02d", seconds.abs / 3600, (seconds.abs % 3600) / 60)
        end

        # ---- result assembly ----

        def build_totals(current, previous)
          query.metrics.to_h do |metric|
            value = current[:totals].fetch([], {})[metric.name] || zero_for(metric)
            prev = previous && (previous[:totals].fetch([], {})[metric.name] || zero_for(metric))
            [metric.name, metric_payload(value, prev)]
          end
        end

        def build_rows(current, previous)
          return [] if query.dimensions.empty?

          keys = row_keys(current)
          prev_key_map = previous ? previous_key_map(keys) : {}

          rows = keys.map do |key|
            metrics = query.metrics.index_by(&:name).transform_values do |metric|
              value = current[:groups].fetch(key, {})[metric.name] || zero_for(metric)
              prev = previous && (previous[:groups].fetch(prev_key_map.fetch(key, key), {})[metric.name] || zero_for(metric))
              metric_payload(value, prev)
            end

            dimensions = query.dimensions.each_with_index.to_h do |d, index|
              [d[:dimension].name, key[index]]
            end

            { dimensions: dimensions, metrics: metrics }
          end

          sort_rows(rows)
        end

        # Grouped keys observed in the data, plus zero-filled time buckets
        # covering the whole range (time-dimension queries chart every bucket).
        def row_keys(current)
          keys = current[:groups].keys
          time_dim = query.time_dimension
          return keys unless time_dim && query.dimensions.size == 1

          expected_buckets(query.time_range, time_dim[:grain]).map { |bucket| [bucket] }
        end

        def expected_buckets(range, grain)
          from = range.first.in_time_zone(query.time_zone).to_date
          to = range.last.in_time_zone(query.time_zone).to_date

          case grain
          when :day then (from..to).map(&:to_s)
          when :week then step_buckets(from.beginning_of_week(:monday), to) { |d| d + 7 }
          when :month then step_buckets(from.beginning_of_month, to, &:next_month)
          end
        end

        def step_buckets(cursor, to)
          buckets = []
          while cursor <= to
            buckets << cursor.to_s
            cursor = yield(cursor)
          end
          buckets
        end

        # Aligns each current bucket with its previous-period counterpart by
        # POSITION: the nth bucket of this period pairs with the nth bucket of
        # the previous one. Date arithmetic on the bucket itself cannot do this
        # — a range starting mid-week or mid-month has a partial first bucket
        # whose start lies before the range, so shifting it lands outside the
        # comparison window and orphans real data. Only the time component of
        # a key moves; value-dimension components align 1:1.
        def previous_key_map(keys)
          time_dim = query.time_dimension
          return {} unless time_dim

          index = query.dimensions.index(time_dim)
          pairs = bucket_pairs(time_dim[:grain])

          keys.filter_map do |key|
            counterpart = pairs[key[index].to_s]
            next unless counterpart

            shifted = key.dup
            shifted[index] = counterpart
            [key, shifted]
          end.to_h
        end

        # Both periods span the same number of days, so their bucket counts
        # differ by at most one partial edge; pairing from the end keeps the
        # most recent buckets — the ones a merchant reads first — aligned.
        def bucket_pairs(grain)
          current = expected_buckets(query.time_range, grain)
          previous = expected_buckets(query.previous_time_range, grain)
          offset = previous.size - current.size

          current.each_with_index.to_h { |bucket, position| [bucket, previous[position + offset]] }
        end

        # SQL already ordered/limited the pushdown case; this re-sort is a
        # no-op there and covers the multi-base fallback.
        def sort_rows(rows)
          if query.sort
            metric = query.sort[:metric]
            rows = rows.sort_by { |row| row[:metrics][metric][:value] }
            rows.reverse! if query.sort[:direction] == :desc
          end
          rows = rows.first(query.limit) if query.limit
          rows
        end

        def connection
          Spree::Order.connection
        end
      end
    end
  end
end
