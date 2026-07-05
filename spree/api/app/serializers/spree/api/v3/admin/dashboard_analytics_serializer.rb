module Spree
  module Api
    module V3
      module Admin
        class DashboardAnalyticsSerializer
          attr_reader :store, :currency, :time_range, :params

          def initialize(store:, currency:, time_range:, params: {})
            @store = store
            @currency = currency
            @time_range = time_range
            @params = params
          end

          def to_h
            {
              currency: currency,
              date_from: time_range.first.iso8601,
              date_to: time_range.last.iso8601,
              summary: summary,
              chart_data: chart_data,
              top_products: top_products
            }
          end

          private

          def orders
            @orders ||= store.orders.complete.where(currency: currency, completed_at: time_range)
          end

          def prev_orders
            @prev_orders ||= store.orders.complete.where(currency: currency, completed_at: previous_time_range)
          end

          def previous_time_range
            duration = time_range.last - time_range.first
            (time_range.first - duration)..(time_range.last - duration)
          end

          # ---- Summary ----

          def summary
            sales = sales_total
            count = orders_count
            avg = count > 0 ? (sales / count).round(2) : 0.0

            prev_sales = prev_orders.sum(:total).to_f
            prev_count = prev_orders.count
            prev_avg = prev_count > 0 ? (prev_sales / prev_count).round(2) : 0.0

            {
              sales_total: sales.round(2),
              display_sales_total: money(sales),
              sales_growth: growth_rate(sales, prev_sales),
              orders_count: count,
              orders_growth: growth_rate(count, prev_count),
              avg_order_value: avg,
              display_avg_order_value: money(avg),
              avg_order_value_growth: growth_rate(avg, prev_avg)
            }
          end

          def sales_total
            @sales_total ||= orders.sum(:total).to_f
          end

          def orders_count
            @orders_count ||= orders.count
          end

          # ---- Chart data ----

          def chart_data
            daily = orders
              .select("DATE(completed_at) AS day, SUM(total) AS day_total, COUNT(*) AS day_count")
              .group("DATE(completed_at)")
              .order("day")
              .index_by { |r| r.day.to_s }

            (time_range.first.to_date..time_range.last.to_date).map do |date|
              key = date.to_s
              row = daily[key]
              total = row&.day_total.to_f
              count = row&.day_count.to_i || 0
              {
                date: key,
                sales: total.round(2),
                orders: count,
                avg_order_value: count > 0 ? (total / count).round(2) : 0.0
              }
            end
          end

          # ---- Top products ----

          def top_products
            rows = Spree::LineItem
              .joins(:variant)
              .where(order: orders)
              .group('spree_variants.product_id')
              .order(Arel.sql('SUM(spree_line_items.quantity * spree_line_items.price) DESC'))
              .limit(5)
              .pluck(Arel.sql('spree_variants.product_id, SUM(spree_line_items.quantity), SUM(spree_line_items.quantity * spree_line_items.price)'))

            product_ids = rows.map(&:first).compact
            return [] if product_ids.empty?

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
                total: money(amount)
              }
            end
          end

          # ---- Helpers ----

          def money(amount)
            Spree::Money.new(amount, currency: currency).to_s
          end

          def growth_rate(current, previous)
            return 0.0 if previous.zero?
            (((current - previous) / previous.to_f) * 100).round(1)
          end
        end
      end
    end
  end
end
