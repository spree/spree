module Spree
  module Admin
    module Reports
      class Customers
        def initialize(params)
          @params = params
        end

        def call
          users = Spree.user_class.left_outer_joins(:spree_roles)
          users = by_date_range(users)
          users = group(users)

          values = users.map { |day, results| [day, results.size] }
                        .sort_by { |day, _| day }
                        .to_h

          create_report_labels.map do |label|
            [label, values[label] || 0]
          end 
        end

        private

        attr_reader :params

        def create_report_labels
          Spree::Admin::Reports::CreateReportLabels.new.call(
            from: date_from.to_date,
            to: date_to.to_date,
            mode: params[:group_by]
          )
        end

        def date_from
          return (Time.current - 7.days) unless params[:date_from].present?

          Time.zone.parse(params[:date_from])
        end

        def date_to
          return Time.current unless params[:date_to].present?

          Time.zone.parse(params[:date_to])
        end

        def by_date_range(users)
          users = users.where('created_at >= ?', date_from.beginning_of_day)
          users = users.where('created_at < ?', date_to.end_of_day)

          users
        end

        def group_by
          group_by = params[:group_by] || 'day'

          case group_by.to_sym
          when :year
            '%Y'
          when :month
            '%Y-%m'
          else
            '%Y-%m-%d'
          end
        end

        def group(users)
          users.group_by do |user|
            user.created_at.strftime(group_by)
          end
        end
      end
    end
  end
end
