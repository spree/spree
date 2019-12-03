module Spree
  module Admin
    module Reports
      module Orders
        class AverageOrderValues
          def initialize(params)
            @params = params
          end

          def call
            orders = Spree::Order.complete
            orders = by_completed_at_min(orders)
            orders = by_completed_at_max(orders)
            orders = grouped_by(orders)

            orders
              .map { |day, results| [day, results.sum(&:total) / results.size] }
              .sort_by { |day, _| day }
          end

          private

          attr_accessor :params

          def completed_at_min?
            params[:completed_at_min].present?
          end

          def completed_at_max?
            params[:completed_at_max].present?
          end

          def grouped_by(orders)
            orders.group_by { |order| order.completed_at.strftime(group_by_date) }
          end

          def by_completed_at_min(orders)
            return orders unless completed_at_min?

            date = Time.zone.parse(params[:completed_at_min]).beginning_of_day
            orders.where('completed_at >= ?', date)
          end

          def by_completed_at_max(orders)
            return orders unless completed_at_max?

            date = Time.zone.parse(params[:completed_at_max]).end_of_day
            orders.where('completed_at <= ?', date)
          end

          def group_by_date
            group_by = params[:group_by] || 'day'

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
end
