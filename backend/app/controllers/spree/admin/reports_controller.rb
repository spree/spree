module Spree
  module Admin
    class ReportsController < Spree::Admin::BaseController
      respond_to :html

      class << self
        def available_reports
          @@available_reports
        end

        def add_available_report!(report_key, report_description_key = nil)
          if report_description_key.nil?
            report_description_key = "#{report_key}_description"
          end
          @@available_reports[report_key] = {name: Spree.t(report_key), description: Spree.t(report_description_key)}
        end
      end

      def initialize
        super 
        ReportsController.add_available_report!(:sales_total)
      end

      def index
        @reports = ReportsController.available_reports
      end

      def sales_total
        params[:q] = {} unless params[:q]

        if params[:q][:completed_at_gt].blank?
          params[:q][:completed_at_gt] = Time.zone.now.beginning_of_month
        else
          params[:q][:completed_at_gt] = Time.zone.parse(params[:q][:completed_at_gt]).beginning_of_day rescue Time.zone.now.beginning_of_month
        end

        if params[:q] && !params[:q][:completed_at_lt].blank?
          params[:q][:completed_at_lt] = Time.zone.parse(params[:q][:completed_at_lt]).end_of_day rescue ""
        end

        @search = Order.complete.ransack(params[:q])
        @orders = @search.result
        @totals = {}

        item_total = @orders.group(:currency).sum(:item_total)
        adjustment_total = @orders.group(:currency).sum(:adjustment_total)
        sales_total = @orders.group(:currency).sum(:total)
        currencies = item_total.keys

        currencies.each do |currency|
          @totals[currency] = {
            item_total: Spree::Money.new(item_total[currency], currency: currency).money,
            adjustment_total: Spree::Money.new(adjustment_total[currency], currency: currency).money,
            sales_total: Spree::Money.new(sales_total[currency], currency: currency).money
          }
        end
      end

      private

      def model_class
        Spree::Admin::ReportsController
      end

      @@available_reports = {}

    end
  end
end
