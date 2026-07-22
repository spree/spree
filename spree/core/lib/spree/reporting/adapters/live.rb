module Spree
  module Reporting
    module Adapters
      # Compiles reporting queries straight against the transactional schema
      # through store-scoped associations. Default adapter — zero extra infra.
      #
      # Metrics aggregate on their own base relation (:orders or :line_items);
      # one grouped SQL query runs per base per period and the row sets merge
      # on dimension keys. Time buckets resolve in the store's timezone and
      # zero-fill across the requested range.
      class Live < Base
        def execute(query)
          @query = query
          @store = query.store

          current = period_data(query.time_range)
          previous = query.compare? ? period_data(query.previous_time_range) : nil

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

        attr_reader :query, :store

        # ---- period execution ----

        def period_data(range)
          {
            range: range,
            totals: aggregate(range, grouped: false),
            groups: query.dimensions.any? ? aggregate(range, grouped: true) : {}
          }
        end

        # Runs one SQL query per metric base; returns { key_tuple => { metric => value } }.
        # Ungrouped aggregates use the single [] key.
        def aggregate(range, grouped:)
          rows = Hash.new { |h, k| h[k] = {} }

          query.aggregated_metrics.group_by(&:base).each do |base, metrics|
            scope = base_scope(base, range)
            selects = metrics.map { |m| "#{resolve_sql(m.sql)} AS #{metric_alias(m)}" }

            if grouped
              dimension_selects = query.dimensions.map do |d|
                "#{dimension_expression(d, base)} AS #{dimension_alias(d)}"
              end
              scope = scope.group(query.dimensions.map { |d| Arel.sql(dimension_expression(d, base)) })
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

        # The completed_at range predicate implies completeness, so neither
        # base needs the `complete` scope on top (merging it would replace the
        # range condition — Rails merge overwrites same-column wheres).
        def base_scope(base, range)
          scope = case base
                  when :orders
                    store.orders.where(currency: query.currency, completed_at: range)
                  when :line_items
                    store.line_items
                      .where(Spree::Order.table_name => { currency: query.currency, completed_at: range })
                  else
                    raise InvalidQuery, "unknown metric base #{base}"
                  end

          # Association default orderings break grouped selects on PostgreSQL.
          scope = scope.reorder(nil)
          scope = apply_dimension_joins(scope, base)
          apply_filters(scope, base)
        end

        def apply_dimension_joins(scope, base)
          query.dimensions.each do |d|
            joins = d[:dimension].joins
            scope = scope.joins(joins) if joins.present? && d[:dimension].base == base_for_joins(base)
          end
          scope
        end

        # Dimension joins are declared from their own base; they only apply
        # when the executing scope is that base (an :orders-based metric never
        # joins line-item tables — validate_bases! guarantees compatibility).
        def base_for_joins(base)
          base
        end

        def apply_filters(scope, base)
          query.filters.each do |filter|
            column = qualified_column(filter[:dimension], base)
            scope = scope.joins(filter[:dimension].joins) if filter[:dimension].joins.present? && base == :line_items
            scope = scope.where("#{column} IN (?)", filter[:values])
          end
          scope
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
                 classifications: Spree::Classification.table_name)
        end

        def dimension_alias(dim)
          "d_#{dim[:dimension].name}"
        end

        def dimension_expression(dim, base)
          dimension = dim[:dimension]
          return time_bucket_sql(qualified_column(dimension, base), dim[:grain]) if dimension.time?

          qualified_column(dimension, base)
        end

        def qualified_column(dimension, _base)
          return resolve_sql(dimension.column) if dimension.column.is_a?(String)

          table = dimension.base == :orders ? Spree::Order.table_name : Spree::LineItem.table_name
          "#{table}.#{dimension.column}"
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
            tz = store_time_zone.tzinfo.identifier
            case grain
            when :day then "(#{column} AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date"
            when :month then "date_trunc('month', #{column} AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date"
            end
          when /mysql/i
            offset = format_offset(utc_offset)
            case grain
            when :day then "DATE(CONVERT_TZ(#{column}, '+00:00', '#{offset}'))"
            when :month then "DATE_FORMAT(CONVERT_TZ(#{column}, '+00:00', '#{offset}'), '%Y-%m-01')"
            end
          else # SQLite
            case grain
            when :day then "DATE(#{column}, '#{utc_offset} seconds')"
            when :month then "strftime('%Y-%m-01', #{column}, '#{utc_offset} seconds')"
            end
          end
        end

        def store_time_zone
          @store_time_zone ||= ActiveSupport::TimeZone[store.preferred_timezone.presence || 'UTC'] || ActiveSupport::TimeZone['UTC']
        end

        def utc_offset
          store_time_zone.now.utc_offset
        end

        def format_offset(seconds)
          sign = seconds.negative? ? '-' : '+'
          format("#{sign}%02d:%02d", seconds.abs / 3600, (seconds.abs % 3600) / 60)
        end

        # ---- result assembly ----

        def build_totals(current, previous)
          query.metrics.to_h do |metric|
            value = current[:totals][[]][metric.name] || zero_for(metric)
            prev = previous && (previous[:totals][[]][metric.name] || zero_for(metric))
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
          from = range.first.in_time_zone(store_time_zone).to_date
          to = range.last.in_time_zone(store_time_zone).to_date

          case grain
          when :day then (from..to).map(&:to_s)
          when :month
            months = []
            cursor = from.beginning_of_month
            while cursor <= to
              months << cursor.to_s
              cursor = cursor.next_month
            end
            months
          end
        end

        # Aligns each current bucket with its previous-period counterpart
        # (same offset from the range start); value-dimension keys align 1:1.
        def previous_key_map(keys)
          time_dim = query.time_dimension
          return {} unless time_dim && query.dimensions.size == 1

          span = offset_span(time_dim[:grain])
          keys.to_h do |key|
            date = Date.parse(key.first.to_s)
            prev = time_dim[:grain] == :day ? date - span : date << span
            [key, [prev.to_s]]
          end
        rescue Date::Error
          {}
        end

        def offset_span(grain)
          from = query.time_range.first.in_time_zone(store_time_zone).to_date
          to = query.time_range.last.in_time_zone(store_time_zone).to_date

          case grain
          when :day then (to - from).to_i + 1
          when :month then ((to.year - from.year) * 12) + (to.month - from.month) + 1
          end
        end

        def sort_rows(rows)
          if query.sort
            metric = query.sort[:metric]
            rows = rows.sort_by { |row| row[:metrics][metric][:value] }
            rows.reverse! if query.sort[:direction] == :desc
          end
          rows = rows.first(query.limit) if query.limit
          rows
        end

        # ---- metric math ----

        def apply_derived(metrics)
          query.metrics.select(&:derived?).each do |metric|
            numerator, denominator = metric.ratio.map { |name| metrics[name] || 0 }
            metrics[metric.name] = denominator.to_f.zero? ? 0.0 : (numerator / denominator.to_f).round(2)
          end
        end

        def metric_payload(value, previous)
          payload = { value: value }
          if query.compare?
            payload[:previous] = previous
            payload[:growth] = growth_rate(value, previous)
          end
          payload
        end

        def cast_value(metric, raw)
          case metric.format
          when :money, :decimal then raw.to_f.round(2)
          else raw.to_i
          end
        end

        def zero_for(metric)
          metric.format == :integer ? 0 : 0.0
        end

        # Percentage change vs the previous period. nil when there is no
        # previous-period baseline (previous == 0 with current activity) so
        # clients can render "new" instead of a misleading 0%.
        def growth_rate(current, previous)
          return nil if previous.nil?
          if previous.zero?
            return 0.0 if current.zero?

            return nil
          end

          (((current - previous) / previous.to_f) * 100).round(1)
        end

        def connection
          Spree::Order.connection
        end
      end
    end
  end
end
