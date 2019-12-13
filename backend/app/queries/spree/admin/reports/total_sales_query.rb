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
            .sort_by { |day, _| day }
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
          if opts[:date_from]
            min = Time.zone.parse(opts[:date_from]).beginning_of_day
            scope = scope.where('completed_at >= ?', min)
          end

          if opts[:date_to]
            max = Time.zone.parse(opts[:date_to]).end_of_day
            scope = scope.where('completed_at <= ?', max)
          end

          scope
        end
      end
    end
  end
end
