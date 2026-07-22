module Spree
  module Api
    module V3
      module Admin
        # Builds the home dashboard analytics payload: KPI summary and daily
        # chart series for a time range, each compared against the immediately
        # preceding period of equal length, plus top products with
        # period-over-period growth.
        class DashboardAnalyticsSerializer
          include DashboardSerializerHelpers

          TOP_PRODUCTS_LIMIT = 5

          attr_reader :store, :currency, :time_range, :channel, :params

          def initialize(store:, currency:, time_range:, channel: nil, params: {})
            @store = store
            @currency = currency
            @time_range = time_range
            @channel = channel
            @params = params
          end

          def to_h
            {
              currency: currency,
              channel_id: channel&.prefixed_id,
              date_from: time_range.first.iso8601,
              date_to: time_range.last.iso8601,
              previous_date_from: previous_time_range.first.iso8601,
              previous_date_to: previous_time_range.last.iso8601,
              summary: summary,
              chart_data: chart_data,
              top_products: top_products
            }
          end

          private

          def base_orders
            store.orders.complete.where(currency: currency).for_channel(channel)
          end

          def orders
            @orders ||= base_orders.where(completed_at: time_range)
          end

          def prev_orders
            @prev_orders ||= base_orders.where(completed_at: previous_time_range)
          end

          def previous_time_range
            @previous_time_range ||= begin
              duration = time_range.last - time_range.first
              (time_range.first - duration)..(time_range.last - duration)
            end
          end

          # ---- Summary ----

          def summary
            sales, count, customers = period_totals(orders)
            prev_sales, prev_count, prev_customers = period_totals(prev_orders)
            avg = count > 0 ? (sales / count).round(2) : 0.0
            prev_avg = prev_count > 0 ? (prev_sales / prev_count).round(2) : 0.0
            units = store.line_items.where(order: orders).sum(:quantity)
            prev_units = store.line_items.where(order: prev_orders).sum(:quantity)

            {
              sales_total: sales.round(2),
              display_sales_total: money(sales),
              sales_growth: growth_rate(sales, prev_sales),
              orders_count: count,
              orders_growth: growth_rate(count, prev_count),
              avg_order_value: avg,
              display_avg_order_value: money(avg),
              avg_order_value_growth: growth_rate(avg, prev_avg),
              units_sold: units,
              units_growth: growth_rate(units, prev_units),
              customers_count: customers,
              customers_growth: growth_rate(customers, prev_customers)
            }
          end

          # One aggregate pass per period: sales total, order count, distinct
          # customers.
          def period_totals(scope)
            sales, count, customers = scope.pick(Arel.sql('SUM(total), COUNT(*), COUNT(DISTINCT email)'))

            [sales.to_f, count.to_i, customers.to_i]
          end

          # ---- Chart data ----

          # Each entry carries the current day's metrics plus the metrics of the
          # matching day in the previous period (same offset from the range
          # start), so the chart can overlay both series point-for-point.
          def chart_data
            daily = daily_metrics(orders)
            prev_daily = daily_metrics(prev_orders)
            daily_units = daily_unit_sums(orders)
            prev_daily_units = daily_unit_sums(prev_orders)
            span = (time_range.last.to_date - time_range.first.to_date).to_i + 1

            (time_range.first.to_date..time_range.last.to_date).map do |date|
              prev_date = date - span
              current = day_metrics(daily[date.to_s], daily_units[date.to_s])
              previous = day_metrics(prev_daily[prev_date.to_s], prev_daily_units[prev_date.to_s])
              {
                date: date.to_s,
                previous_date: prev_date.to_s,
                sales: current[:sales],
                orders: current[:orders],
                avg_order_value: current[:avg_order_value],
                units: current[:units],
                customers: current[:customers],
                previous_sales: previous[:sales],
                previous_orders: previous[:orders],
                previous_avg_order_value: previous[:avg_order_value],
                previous_units: previous[:units],
                previous_customers: previous[:customers]
              }
            end
          end

          def daily_metrics(scope)
            scope
              .select('DATE(completed_at) AS day, SUM(total) AS day_total, COUNT(*) AS day_count, COUNT(DISTINCT email) AS day_customers')
              .group('DATE(completed_at)')
              .index_by { |r| r.day.to_s }
          end

          # `store.line_items` goes through `orders`, so `spree_orders` is
          # already joined and referencable in the GROUP BY.
          def daily_unit_sums(order_scope)
            store.line_items
              .where(order: order_scope)
              .group(Arel.sql("DATE(#{Spree::Order.table_name}.completed_at)"))
              .sum(:quantity)
              .transform_keys(&:to_s)
          end

          def day_metrics(row, units)
            total = row&.day_total.to_f
            count = row&.day_count.to_i || 0
            {
              sales: total.round(2),
              orders: count,
              avg_order_value: count > 0 ? (total / count).round(2) : 0.0,
              units: units.to_i,
              customers: row&.day_customers.to_i || 0
            }
          end

          # ---- Top products ----

          def top_products
            rows = product_revenue(orders).limit(TOP_PRODUCTS_LIMIT)
              .pluck(Arel.sql("#{Spree::Variant.table_name}.product_id, SUM(#{Spree::LineItem.table_name}.quantity), #{revenue_sum_sql}"))

            product_ids = rows.map(&:first).compact
            return [] if product_ids.empty?

            prev_amounts = product_revenue(prev_orders)
              .where(Spree::Variant.table_name => { product_id: product_ids })
              .pluck(Arel.sql("#{Spree::Variant.table_name}.product_id, #{revenue_sum_sql}"))
              .to_h

            products = store.products.with_deleted.includes(:primary_media).where(id: product_ids)
            product_serializer = Spree.api.admin_product_serializer

            rows.filter_map do |product_id, quantity, amount|
              product = products.find { |p| p.id == product_id }
              next unless product

              serialized = product_serializer.new(product, params: params).to_h
              {
                id: serialized['id'],
                name: serialized['name'],
                slug: serialized['slug'],
                image_url: serialized['thumbnail_url'],
                price: serialized.dig('price', 'display_amount'),
                quantity: quantity.to_i,
                amount: amount.to_f.round(2),
                total: money(amount),
                growth: growth_rate(amount.to_f, prev_amounts[product_id].to_f)
              }
            end
          end

          def product_revenue(order_scope)
            store.line_items
              .joins(:variant)
              .where(order: order_scope)
              .group("#{Spree::Variant.table_name}.product_id")
              .order(Arel.sql("#{revenue_sum_sql} DESC"))
          end

          # ---- Helpers ----

          # Percentage change vs the previous period. Returns nil when there is
          # no previous-period baseline (previous == 0 with current activity) so
          # clients can render "new" instead of a misleading 0%.
          def growth_rate(current, previous)
            if previous.zero?
              return 0.0 if current.zero?

              return nil
            end

            (((current - previous) / previous.to_f) * 100).round(1)
          end
        end
      end
    end
  end
end
