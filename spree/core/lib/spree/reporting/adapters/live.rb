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
        # Roughly a century — long enough for any report a merchant would read,
        # short enough that the widest one still fits in memory at day grain.
        MAX_RANGE_DAYS = 36_600
        COMPARISON_OPERATORS = { eq: '=', gt: '>', gte: '>=', lt: '<', lte: '<=' }.freeze
        COMPARISON_METHODS = { eq: :==, gt: :>, gte: :>=, lt: :<, lte: :<= }.freeze

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
          # Cart metrics are judged by the clock at the end of the period being
          # aggregated, so the memoized placeholders are rebuilt per period.
          self.aggregating_range = range

          query.aggregated_metrics.group_by(&:base).each do |base, metrics|
            scope = base_scope(base, range, grouped: grouped)
            selects = metrics.map { |m| "#{resolve_sql(m.sql_for(grouped: grouped))} AS #{metric_alias(m)}" }

            if grouped
              dimension_selects = query.dimensions.map do |d|
                "#{dimension_expression(d)} AS #{dimension_alias(d)}"
              end
              scope = scope.group(query.dimensions.map { |d| Arel.sql(group_by_term(d)) })
              scope = apply_key_filter(scope, key_filter) if key_filter
              scope = apply_metric_filters(scope, metrics) unless query.include_empty?
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

        # The base's own registered relation, already store-scoped and
        # range-filtered. Sales bases need no `complete` scope on top of the
        # range predicate (merging it would replace the range condition — Rails
        # merge overwrites same-column wheres), and exclude canceled orders
        # explicitly: sales figures count what stayed sold.
        def base_relation(base, range)
          scope = query.registry.base!(base).relation.call(query.store, range, query.scope_currency)

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

        # Metric filters compile to HAVING and so apply to the grouped query
        # only — the Total row stays the period's real figure rather than the
        # sum of the rows that happened to survive the filter (Decision 13:
        # rows need not sum to the total).
        #
        # Skipped entirely under include_empty: HAVING would drop the rows that
        # do not match, and the population merge would then reintroduce them as
        # zeros — so a bestseller would come back looking like it never sold.
        # Those queries filter once, in Ruby, over the merged values.
        #
        # Only filters whose metric this base aggregates are applied; a query
        # spanning two bases runs one SQL statement per base, and a HAVING
        # naming another base's column would not compile.
        def apply_metric_filters(scope, metrics)
          names = metrics.map(&:name)

          query.metric_filters.each do |filter|
            metric = filter[:metric]
            next unless names.include?(metric.name)

            # The value rides as a bind rather than an interpolation: it is
            # the only piece of request data that reaches the statement, and
            # the aggregate beside it is registered SQL.
            scope = scope.having(
              Arel.sql("#{resolve_sql(metric.sql_for(grouped: true))} " \
                       "#{COMPARISON_OPERATORS.fetch(filter[:op])} ?"),
              filter[:value]
            )
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
          node = Arel::Nodes::SqlLiteral.new(column)
          present, null = Array(values).partition { |value| !value.nil? }
          # `IN (NULL)` never matches, so a NULL group would silently drop out
          # of the comparison period and report a zero previous value.
          return node.in(present) if null.empty?
          return node.eq(nil) if present.empty?

          node.in(present).or(node.eq(nil))
        end

        # Dimension joins are declared from the dimension's own base. Reaching
        # an :orders dimension (e.g. the ship address) from the :line_items
        # base goes through the order association.
        # LEFT joins, always. A dimension's association is frequently optional —
        # an order need not have a shipping address, a product need not be in a
        # category — and an inner join drops those rows from the breakdown
        # while the ungrouped Total still counts them, so the rows quietly fail
        # to add up. Left-joining produces a NULL key instead, which is a real
        # group the hydration already renders as "Unassigned".
        def join_for(scope, dimension, base)
          return scope if dimension.joins.blank?
          return scope.left_joins(dimension.joins) if dimension.base == base
          return scope.left_joins(order: dimension.joins) if base == :line_items && dimension.base == :orders

          scope
        end

        # ---- sorted/limited rankings ----

        # ORDER BY + LIMIT can move into SQL when one base group carries every
        # aggregated metric (so the sort metric and the limit apply to the
        # same query) and the grouping is by value, not time buckets.
        # include_empty is excluded: pushing LIMIT into the grouped SQL would
        # cut the result before the dimension's full population is merged in,
        # so the members with no rows — the ones being asked about — would be
        # the first to fall off.
        def sql_sortable?
          return @sql_sortable unless @sql_sortable.nil?

          @sql_sortable = query.sort && query.limit && query.time_dimension.nil? && query.dimensions.any? &&
            !query.include_empty? && !sort_metric.derived? &&
            query.aggregated_metrics.map(&:base).uniq.one? || false
        end

        def sort_metric
          @sort_metric ||= query.registry.metric!(query.sort[:metric])
        end

        def apply_sql_sort(scope, metrics)
          return scope unless metrics.any? { |m| m.name == sort_metric.name }

          scope.order(Arel.sql("#{resolve_sql(sort_metric.sql_for(grouped: true))} " \
                               "#{query.sort[:direction] == :desc ? 'DESC' : 'ASC'}"))
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

        # A bare `column:` symbol is read from its own base's table, which the
        # base declares. Guessing it from a two-way ternary silently read every
        # base but :orders as line items.
        def base_table(base)
          resolve_sql(query.registry.base!(base).table)
        end

        # Registered fragments defer table names as %{placeholders} because
        # model classes cannot load while initializers register the vocabulary.
        # The cutoff rides along because it is the one value a fragment needs
        # that is not a table name — see #abandoned_cutoff.
        def resolve_sql(fragment)
          format(fragment, placeholders)
        end

        def placeholders
          @placeholders ||= {
            orders: Spree::Order.table_name,
            line_items: Spree::LineItem.table_name,
            variants: Spree::Variant.table_name,
            products: Spree::Product.table_name,
            addresses: Spree::Address.table_name,
            product_categories: Spree::ProductCategory.table_name,
            refunds: Spree::Refund.table_name,
            fees: Spree::Fee.table_name,
            commission_lines: Spree::CommissionLine.table_name,
            payments: Spree::Payment.table_name,
            stock_movements: Spree::StockMovement.table_name,
            stock_levels: Spree::StockLevel.table_name,
            carts: Spree::Cart.table_name,
            discounts: Spree::Discount.table_name,
            promotions: Spree::Promotion.table_name
          }.merge(abandoned_cutoff: abandoned_cutoff)
        end

        # The instant a cart must have been quiet since to count as abandoned:
        # the store's window measured back from the end of the period being
        # aggregated, not from now.
        #
        # Measuring from now would make every unconverted cart in a comparison
        # period abandoned — that whole window lies further in the past than
        # any cutoff — so a year-on-year abandonment chart would show a
        # fabricated collapse. A period's carts are judged by the clock at the
        # end of that period.
        def abandoned_cutoff
          hours = query.store.preferred_abandoned_cart_after_hours.to_i.hours
          connection.quote((aggregating_range.last - hours).utc)
        end

        # The period currently being aggregated. Defaults to the query's own
        # range so anything reading placeholders before #aggregate runs (a sort
        # term, a dimension expression) still resolves.
        def aggregating_range
          @aggregating_range || query.time_range
        end

        def aggregating_range=(range)
          @aggregating_range = range
          @placeholders = nil
        end

        def dimension_alias(dim)
          "d_#{dim[:dimension].name}"
        end

        # What GROUP BY names for a dimension. A plain column repeats its
        # expression, but an expression dimension groups by the SELECT alias:
        # MySQL's only_full_group_by refuses to match a repeated expression
        # containing a correlated subquery, seeing only the bare column inside
        # it. All three databases accept grouping by the alias.
        def group_by_term(dim)
          dim[:dimension].expression? ? dimension_alias(dim) : dimension_expression(dim)
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
          return resolve_sql(dimension.expression) if dimension.expression?

          resolved = if dimension.column.is_a?(String)
                       resolve_sql(dimension.column)
                     else
                       "#{base_table(dimension.base)}.#{dimension.column}"
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
        # Time keys are normalized to the string form #expected_buckets emits,
        # because each database returns a different Ruby type for a bucket
        # (Postgres a Time for date_trunc, SQLite a String) and the zero-fill
        # has to match the aggregated rows exactly or every bucket duplicates.
        def dimension_key(dim, raw)
          return raw unless dim[:dimension].time?
          return raw.to_s unless dim[:grain] == :hour

          # MySQL and SQLite format the bucket themselves; only PostgreSQL's
          # date_trunc hands back a Time.
          raw.respond_to?(:strftime) ? raw.strftime('%Y-%m-%d %H:00:00') : raw.to_s
        end

        # Store-timezone day/month buckets, per database. PostgreSQL converts
        # properly (DST-aware); SQLite/MySQL shift by the timezone's current
        # UTC offset — a documented approximation near DST boundaries.
        # A grain this method does not know would return nil and silently
        # group every row under one NULL bucket, so an unhandled grain raises
        # here rather than producing a plausible-looking wrong series. Adding a
        # grain means teaching this method and #expected_buckets together.
        def time_bucket_sql(column, grain)
          sql =
            case connection.adapter_name
            when /postgres/i
              local = "#{column} AT TIME ZONE 'UTC' AT TIME ZONE '#{query.time_zone.tzinfo.identifier}'"
              case grain
              when :hour then "date_trunc('hour', #{local})"
              when :day then "(#{local})::date"
              when :week then "date_trunc('week', #{local})::date"
              when :month then "date_trunc('month', #{local})::date"
              end
            when /mysql/i
              local = "CONVERT_TZ(#{column}, '+00:00', '#{format_offset(utc_offset)}')"
              case grain
              when :hour then "DATE_FORMAT(#{local}, '%Y-%m-%d %H:00:00')"
              when :day then "DATE(#{local})"
              when :week then "DATE(DATE_SUB(#{local}, INTERVAL WEEKDAY(#{local}) DAY))"
              when :month then "DATE_FORMAT(#{local}, '%Y-%m-01')"
              end
            else # SQLite — weeks start on Monday (ISO), matching the other adapters
              case grain
              when :hour then "strftime('%Y-%m-%d %H:00:00', #{column}, '#{utc_offset} seconds')"
              when :day then "DATE(#{column}, '#{utc_offset} seconds')"
              when :week then "DATE(#{column}, '#{utc_offset} seconds', '+1 day', 'weekday 1', '-7 days')"
              when :month then "strftime('%Y-%m-01', #{column}, '#{utc_offset} seconds')"
              end
            end

          sql || raise(ArgumentError, "reporting adapter has no SQL for the #{grain} grain")
        end


        def utc_offset
          @utc_offset ||= query.time_zone.now.utc_offset
        end

        def format_offset(seconds)
          sign = seconds.negative? ? '-' : '+'
          format("#{sign}%02d:%02d", seconds.abs / 3600, (seconds.abs % 3600) / 60)
        end

        # ---- result assembly ----

        # A per-group metric has no dimensionless figure: MIN() of every
        # customer's lifetime value is one arbitrary customer's, not the
        # store's, so it is reported as nil rather than rendered as a tile.
        def build_totals(current, previous)
          query.metrics.to_h do |metric|
            next [metric.name, { value: nil }] if metric.per_group?

            value = current[:totals].fetch([], {})[metric.name] || zero_for(metric)
            prev = previous && (previous[:totals].fetch([], {})[metric.name] || zero_for(metric))
            [metric.name, metric_payload(value, prev)]
          end
        end

        def build_rows(current, previous)
          return [] if query.dimensions.empty?

          keys = row_keys(current)
          prev_key_map = previous ? previous_key_map(keys) : {}
          metrics_by_name = query.metrics.index_by(&:name)

          rows = keys.map do |key|
            metrics = metrics_by_name.transform_values do |metric|
              value = current[:groups].fetch(key, {})[metric.name] || zero_for(metric)
              prev = previous && (previous[:groups].fetch(prev_key_map.fetch(key, key), {})[metric.name] || zero_for(metric))
              metric_payload(value, prev)
            end

            dimensions = query.dimensions.each_with_index.to_h do |d, index|
              [d[:dimension].name, key[index]]
            end

            { dimensions: dimensions, metrics: metrics }
          end

          sort_rows(filter_merged_rows(rows))
        end

        # Grouped keys observed in the data, plus zero-filled time buckets
        # covering the whole range (time-dimension queries chart every bucket).
        def row_keys(current)
          keys = current[:groups].keys
          time_dim = query.time_dimension

          if time_dim && query.dimensions.size == 1
            return expected_buckets(query.time_range, time_dim[:grain]).map { |bucket| [bucket] }
          end

          empty_dim = query.dimensions.find { |d| d[:include_empty] }
          return keys unless empty_dim

          # The dimension's whole population leads, so members with no rows in
          # the period still appear (and read zero through build_rows' own
          # `|| zero_for`). This is what answers "which products never sold" —
          # a HAVING alone cannot, because a product that never sold has no
          # row to filter.
          (empty_member_keys(empty_dim, keys) | keys)
        end

        # Members merged in by `include_empty` never went through the grouped
        # SQL, so HAVING never saw them and they arrive zero-filled. Without
        # re-applying the filters here, "which products never sold" would list
        # every product: the bestsellers HAVING removed come back as zeros.
        #
        # Only needed for the include_empty path — everything else was already
        # filtered in SQL, and re-testing it would be a second implementation
        # of the same predicate.
        def filter_merged_rows(rows)
          return rows if query.metric_filters.empty? || !query.include_empty?

          rows.select do |row|
            query.metric_filters.all? do |filter|
              value = row[:metrics].dig(filter[:metric].name, :value)
              next true if value.nil?

              value.to_d.public_send(COMPARISON_METHODS.fetch(filter[:op]), filter[:value])
            end
          end
        end

        # Applies any filter on the dimension itself to its own population. A
        # filter on a *different* dimension cannot narrow this list — it
        # describes the facts, not the members — so a query filtered by
        # something else refuses rather than silently listing members the
        # filter never applied to.
        def narrow_population(relation, dimension)
          query.filters.each do |filter|
            next unless filter[:dimension].name == dimension.name

            relation = relation.where(id: filter[:values])
          end
          relation
        end

        # Ids of every record the dimension can group by, store-scoped through
        # its own lookup relation.
        # Bounded by the query's own limit: these rows all read zero, so beyond
        # a page of them there is nothing more to say, and an unbounded pluck
        # would load a whole catalogue to render fifty rows.
        def empty_member_keys(dim, observed)
          relation = dim[:dimension].population&.call(query.store)
          return [] if relation.nil?

          # The aggregating scope is filtered, so the population must be too:
          # asking "which of these shoes never sold" must not answer with every
          # unsold product in the catalogue.
          relation = narrow_population(relation, dim[:dimension])
          relation = relation.where.not(id: observed.flatten) if observed.any?
          # Ordered before limiting: without it two identical "which products
          # never sold" requests can come back with different products.
          relation = relation.reorder(:id).limit(query.limit) if query.limit
          relation.pluck(:id).map { |id| [id] }
        end

        # Every bucket in the range becomes a row, so an absurd range is an
        # absurd allocation: `last_500000_days`, or a `since` in the year one,
        # would build millions of rows here and take the process down long
        # before any of them reached a chart. Refused rather than trimmed —
        # silently charting a different range than was asked for is worse.
        def expected_buckets(range, grain)
          from = range.first.in_time_zone(query.time_zone).to_date
          to = range.last.in_time_zone(query.time_zone).to_date
          span = (to - from).to_i + 1
          if span > MAX_RANGE_DAYS
            raise InvalidQuery,
                  "time_range covers #{span} days, more than the #{MAX_RANGE_DAYS} a single report may chart"
          end

          case grain
          when :hour then hour_buckets(range)
          when :day then (from..to).map(&:to_s)
          when :week then step_buckets(from.beginning_of_week(:monday), to) { |d| d + 7 }
          when :month then step_buckets(from.beginning_of_month, to, &:next_month)
          end
        end

        # Hour buckets are datetimes rather than dates, so they zero-fill from
        # the range's own edges. Query::MAX_BUCKETS has already refused a range
        # too wide to chart at this grain.
        # Stepping by an hour crosses the repeated local hour on a DST
        # fall-back, where two distinct instants render as the same wall-clock
        # string — so the labels are de-duplicated. Keeping both would render
        # that hour twice and collide the comparison-period keys.
        def hour_buckets(range)
          cursor = range.first.in_time_zone(query.time_zone).change(min: 0, sec: 0)
          last = range.last.in_time_zone(query.time_zone)
          buckets = []
          while cursor <= last
            buckets << cursor.strftime('%Y-%m-%d %H:00:00')
            cursor += 1.hour
          end
          buckets.uniq
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
        # differ by at most one partial edge. Pairing runs from the start —
        # the nth bucket of this period with the nth of the previous — because
        # the ranges share a start offset: a range beginning mid-month pairs
        # its partial first bucket with the previous period's partial first
        # bucket. A bucket past the end of the previous list has no
        # counterpart and pairs with nothing rather than wrapping around.
        def bucket_pairs(grain)
          current = expected_buckets(query.time_range, grain)
          previous = expected_buckets(query.previous_time_range, grain)

          current.each_with_index.to_h { |bucket, position| [bucket, previous[position]] }
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
