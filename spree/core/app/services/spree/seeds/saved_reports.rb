module Spree
  module Seeds
    # The classic report set every store starts with on the Reports page.
    # Idempotent per store (matched by name); merchants can edit or delete
    # them, so a missing seeded report is not recreated once removed by hand —
    # only never-created ones are added.
    class SavedReports
      prepend Spree::ServiceModule::Base

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

      def call
        Spree::Store.find_each do |store|
          # Compared case-insensitively like the model's uniqueness rule, so a
          # merchant's own "top products" never makes a re-seed raise.
          existing = store.saved_reports.pluck(:name).map(&:downcase).to_set

          REPORTS.each do |report|
            # Every locale's name for this report, not just the current one:
            # the name is translated, so a store seeded in one language and
            # re-seeded in another would otherwise recognise none of its own
            # built-ins and create a second full set.
            next if known_names(report[:key]).intersect?(existing)

            store.saved_reports.create!(
              name: Spree.t("reporting.seeds.#{report[:key]}.name"),
              description: Spree.t("reporting.seeds.#{report[:key]}.description"),
              query: report[:query],
              seeded: true
            )
          end
        end
      end

      private

      # The downcased name this report carries in every locale core ships.
      def known_names(key)
        @known_names ||= {}
        @known_names[key] ||= Spree.available_locales.filter_map do |locale|
          Spree.t("reporting.seeds.#{key}.name", locale: locale, default: nil)&.downcase
        end.to_set
      end
    end
  end
end
