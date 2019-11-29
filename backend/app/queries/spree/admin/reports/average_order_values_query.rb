module Spree
  module Admin
    module Reports
      class AverageOrderValuesQuery
        def call(opts)
          @opts = opts

          Spree::Order
            .complete
            .group_by { |order| order.completed_at.strftime(group_by_date) }
            .map { |day, orders| [day, orders.sum(&:total) / orders.size] }
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
      end
    end
  end
end
