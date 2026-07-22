module Spree
  module Api
    module V3
      module Admin
        # Builds the home dashboard rankings payload: top customers and top
        # categories by revenue for a time range.
        class DashboardRankingsSerializer
          DEFAULT_LIMIT = 5
          MAX_LIMIT = 10

          attr_reader :store, :currency, :time_range, :limit

          def initialize(store:, currency:, time_range:, limit: DEFAULT_LIMIT)
            @store = store
            @currency = currency
            @time_range = time_range
            @limit = limit.to_i.clamp(1, MAX_LIMIT)
          end

          def to_h
            {
              currency: currency,
              date_from: time_range.first.iso8601,
              date_to: time_range.last.iso8601,
              customers: customers,
              categories: categories
            }
          end

          private

          def orders
            @orders ||= store.orders.complete.where(currency: currency, completed_at: time_range)
          end

          def customers
            rows = orders
              .group(:email)
              .order(Arel.sql('SUM(total) DESC'))
              .limit(limit)
              .pluck(Arel.sql('email, SUM(total), COUNT(*), MAX(user_id)'))

            users = Spree.user_class.where(id: rows.map(&:last).compact).index_by(&:id)

            rows.map do |email, amount, orders_count, user_id|
              user = users[user_id]
              {
                id: user&.prefixed_id,
                email: email,
                name: user&.full_name.presence || email,
                orders_count: orders_count.to_i,
                amount: amount.to_f.round(2),
                display_amount: money(amount)
              }
            end
          end

          def categories
            rows = Spree::LineItem
              .joins(variant: { product: :classifications })
              .where(order: orders)
              .group("#{Spree::Classification.table_name}.taxon_id")
              .order(Arel.sql("SUM(#{Spree::LineItem.table_name}.quantity * #{Spree::LineItem.table_name}.price) DESC"))
              .limit(limit)
              .pluck(Arel.sql("#{Spree::Classification.table_name}.taxon_id, SUM(#{Spree::LineItem.table_name}.quantity), SUM(#{Spree::LineItem.table_name}.quantity * #{Spree::LineItem.table_name}.price)"))

            taxons = Spree::Taxon.where(id: rows.map(&:first)).index_by(&:id)

            rows.filter_map do |taxon_id, quantity, amount|
              taxon = taxons[taxon_id]
              next unless taxon

              {
                id: taxon.prefixed_id,
                name: taxon.name,
                quantity: quantity.to_i,
                amount: amount.to_f.round(2),
                display_amount: money(amount)
              }
            end
          end

          def money(amount)
            Spree::Money.new(amount, currency: currency).to_s
          end
        end
      end
    end
  end
end
