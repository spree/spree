module Spree
  module Stores
    # The preset reports every store starts with. They are product
    # definitions rather than merchant configuration — translated, read-only
    # (`seeded`), and found by the dashboard under their translated name — so
    # the store creates them itself, the way it creates its default channel.
    module BuiltInReports
      extend ActiveSupport::Concern

      REPORTS = [
        { key: 'sales_over_time',
          query: { 'metrics' => %w[total_sales orders average_order_value], 'dimensions' => [{ 'name' => 'completed_at', 'grain' => 'day' }],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'compare' => 'previous_period' } },
        { key: 'net_sales_over_time',
          query: { 'metrics' => %w[gross_sales discounts returns net_sales], 'dimensions' => [{ 'name' => 'completed_at', 'grain' => 'week' }],
                   'time_range' => { 'preset' => 'last_12_months' }, 'compare' => 'previous_period' } },
        { key: 'sales_by_channel',
          query: { 'metrics' => %w[total_sales orders], 'dimensions' => %w[channel],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-total_sales' } },
        { key: 'sales_by_market',
          query: { 'metrics' => %w[total_sales orders], 'dimensions' => %w[market],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-total_sales' } },
        { key: 'sales_by_country',
          query: { 'metrics' => %w[total_sales orders], 'dimensions' => %w[country],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-total_sales' } },
        { key: 'top_products',
          query: { 'metrics' => %w[net_sales units_sold], 'dimensions' => %w[product],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-net_sales', 'limit' => 20 } },
        { key: 'top_categories',
          query: { 'metrics' => %w[net_sales units_sold], 'dimensions' => %w[category],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-net_sales', 'limit' => 20 } },
        { key: 'top_companies',
          query: { 'metrics' => %w[total_sales orders], 'dimensions' => %w[company],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-total_sales', 'limit' => 20 } },
        { key: 'top_customers',
          query: { 'metrics' => %w[total_sales orders], 'dimensions' => %w[customer],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-total_sales', 'limit' => 20 } },
        { key: 'product_margin',
          query: { 'metrics' => %w[net_sales cost_of_goods gross_profit gross_margin], 'dimensions' => %w[product],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-gross_profit', 'limit' => 20 } },
        { key: 'returns_over_time',
          query: { 'metrics' => %w[returns orders], 'dimensions' => [{ 'name' => 'completed_at', 'grain' => 'month' }],
                   'time_range' => { 'preset' => 'last_12_months' }, 'compare' => 'previous_period' } },
        { key: 'first_time_vs_returning',
          query: { 'metrics' => %w[total_sales orders customers], 'dimensions' => %w[customer_type],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'compare' => 'previous_period' } },
        { key: 'seller_payouts',
          query: { 'metrics' => %w[net_sales commission seller_payout units_sold], 'dimensions' => %w[seller],
                   'time_range' => { 'preset' => 'last_month' }, 'sort' => '-seller_payout', 'limit' => 50 } },
        { key: 'payments_over_time',
          query: { 'metrics' => %w[payments_received payments_refunded net_payments], 'dimensions' => [{ 'name' => 'paid_at', 'grain' => 'day' }],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'compare' => 'previous_period' } },
        { key: 'payments_by_method',
          query: { 'metrics' => %w[net_payments payments_count], 'dimensions' => %w[payment_method],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-net_payments' } },
        { key: 'failed_payments',
          query: { 'metrics' => %w[payments_failed payments_count], 'dimensions' => %w[payment_method],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-payments_failed' } },
        { key: 'stock_movement_over_time',
          query: { 'metrics' => %w[units_received units_shipped], 'dimensions' => [{ 'name' => 'moved_at', 'grain' => 'week' }],
                   'time_range' => { 'preset' => 'last_12_months' } } },
        { key: 'sell_through_by_variant',
          query: { 'metrics' => %w[units_shipped units_received sell_through], 'dimensions' => %w[moved_variant],
                   'time_range' => { 'preset' => 'last_4_weeks' }, 'sort' => '-units_shipped', 'limit' => 20 } },
        { key: 'orders_by_payment_status',
          query: { 'metrics' => %w[orders total_sales], 'dimensions' => %w[payment_status],
                   'time_range' => { 'preset' => 'last_4_weeks' } } },
        { key: 'orders_by_fulfillment_status',
          query: { 'metrics' => %w[orders total_sales], 'dimensions' => %w[fulfillment_status],
                   'time_range' => { 'preset' => 'last_4_weeks' } } }
      ].freeze

      included do
        after_create :insert_built_in_reports
      end

      # Adds the preset reports to a store that has none — one upgraded from
      # before saved reports existed. A store that already has any is left
      # alone, so a built-in the merchant deleted stays deleted.
      #
      # @return [Boolean] whether the reports were added
      def create_built_in_reports
        return false if saved_reports.seeded.exists?

        insert_built_in_reports
        true
      end

      private

      # Inserted in one statement: every query is fixed above.
      def insert_built_in_reports
        now = Time.current
        Spree::SavedReport.insert_all(
          REPORTS.map do |report|
            {
              store_id: id,
              name: Spree.t("reporting.seeds.#{report[:key]}.name"),
              description: Spree.t("reporting.seeds.#{report[:key]}.description"),
              query: report[:query],
              seeded: true,
              created_at: now,
              updated_at: now
            }
          end
        )
      end
    end
  end
end
