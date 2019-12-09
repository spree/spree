module Spree
  module Admin
    module Reports
      module Orders
        class Base

          private

          attr_accessor :params

          def completed_at_min
            @completed_at_min ||= Time.zone.parse(params[:completed_at_min] || '') rescue nil
          end

          def completed_at_max
            @completed_at_max ||= Time.zone.parse(params[:completed_at_max] || '') rescue nil
          end

          def grouped_by(orders)
            orders.group_by { |order| order.completed_at.strftime(group_by_date) }
          end

          def by_completed_at_min(orders)
            return orders unless completed_at_min

            orders.where('completed_at >= ?', completed_at_min.beginning_of_day)
          end

          def by_completed_at_max(orders)
            return orders unless completed_at_max

            orders.where('completed_at <= ?', completed_at_max.end_of_day)
          end

          def group_by_date
            group_by = params[:group_by] || 'day'

            case group_by.to_sym
            when :month then '%Y-%m'
            when :year then '%Y'
            else '%Y-%m-%d'
            end
          end

          def range_missing?
            completed_at_min && completed_at_max
          end

          def create_report_labels
            Spree::Admin::Reports::CreateReportLabels.new.call(
              from: completed_at_min.to_date,
              to: completed_at_max.to_date,
              mode: params[:group_by]
            )
          end
        end
      end
    end
  end
end
