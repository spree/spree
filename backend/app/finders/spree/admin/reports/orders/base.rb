module Spree
  module Admin
    module Reports
      module Orders
        class Base

          private

          attr_accessor :params

          def date_from
            return (Time.current - 7.days) unless params[:date_from].present?

            Time.zone.parse(params[:date_from])
          end

          def date_to
            return Time.current unless params[:date_to].present?

            Time.zone.parse(params[:date_to])
          end

          def grouped_by(orders)
            orders.group_by { |order| order.completed_at.strftime(group_by_date) }
          end

          def by_date_from(orders)
            return orders unless date_from

            orders.where('completed_at >= ?', date_from.beginning_of_day)
          end

          def by_date_to(orders)
            return orders unless date_to

            orders.where('completed_at <= ?', date_to.end_of_day)
          end

          def group_by_date
            group_by = params[:group_by] || 'day'

            case group_by.to_sym
            when :month then '%Y-%m'
            when :year then '%Y'
            else '%Y-%m-%d'
            end
          end

          def create_report_labels
            Spree::Admin::Reports::CreateReportLabels.new.call(
              from: date_from.to_date,
              to: date_to.to_date,
              mode: params[:group_by]
            )
          end
        end
      end
    end
  end
end
