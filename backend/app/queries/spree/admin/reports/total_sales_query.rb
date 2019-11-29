module Spree
  module Admin
    module Reports
      class TotalSalesQuery
        def call(opts)
          @opts = opts

          scope = base_scope
          scope = apply_date_filters(scope)

          scope
            .group_by { |order| order.completed_at.strftime(group_by_date) }
            .map { |day, orders| [day, orders.sum(&:total)] }
        end

        private

        attr_accessor :opts

        def group_by_date
          group_by = opts[:group_by] || 'day'

          case group_by.to_sym
          when :month then '%Y-%m'
          when :year then '%Y'
          else '%Y-%m-%d'
          end
        end

        def base_scope
          Spree::Order.complete
        end

        def apply_date_filters(scope)
          scope = scope.where('completed_at >= ?', opts[:completed_at_min]) if opts[:completed_at_min]
          scope = scope.where('completed_at <= ?', opts[:completed_at_max]) if opts[:completed_at_max]

          scope
        end
      end
    end
  end
end
