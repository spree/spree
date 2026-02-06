module Spree
  module Admin
    module AnalyticsConcern
      extend ActiveSupport::Concern

      included do
        helper_method :analytics_time_range, :same_day?
      end

      def set_analytics_defaults
        params[:analytics_currency] ||= current_currency
        params[:date_from] = try_parse_date_param(params[:date_from]) || 1.month.ago.end_of_day.to_date
        params[:date_to] = try_parse_date_param(params[:date_to]) || Time.zone.now.beginning_of_day.to_date
      end

      def analytics_time_range
        @analytics_time_range ||= (params[:date_from].to_time.beginning_of_day)..(params[:date_to].to_time.end_of_day)
      end

      def previous_analytics_time_range
        duration = analytics_time_range.last - analytics_time_range.first

        @previous_analytics_time_range ||= analytics_time_range.first.ago(duration)..analytics_time_range.last.ago(duration).end_of_day
      end

      def same_day?
        analytics_time_range.first.to_date == analytics_time_range.last.to_date
      end

      def calc_growth_rate(current_amount, previous_amount)
        if previous_amount.zero? && current_amount.positive?
          100
        elsif current_amount.zero? && previous_amount.zero?
          0
        else
          ((current_amount.to_f / previous_amount) * 100) - 100
        end
      end
    end
  end
end
