module Spree
  module Admin
    class ReportsController < BaseController
      before_filter :load_data
      respond_to :html

      AVAILABLE_REPORTS = {
        :sales_total => {:name => I18n.t(:sales_total), :description => I18n.t(:sales_total_description)}
      }

      def index
        @reports = AVAILABLE_REPORTS
        respond_with(@reports)
      end

      def sales_total
        params[:q] = {} unless params[:q]

        if params[:q][:created_at_gt].blank?
          params[:q][:created_at_gt] = Time.zone.now.beginning_of_month
        else
          params[:q][:created_at_gt] = Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day rescue Time.zone.now.beginning_of_month
        end

        if params[:q] && !params[:q][:created_at_lt].blank?
          params[:q][:created_at_lt] = Time.zone.parse(params[:q][:created_at_lt]).end_of_day rescue ""
        end

        if params[:q].delete(:completed_at_not_null) == "1"
          params[:q][:completed_at_not_null] = true
        else
          params[:q][:completed_at_not_null] = false
        end

        params[:q][:meta_sort] ||= "created_at.desc"

        @search = Order.complete.ransack(params[:q])
        @orders = @search.result
        @item_total = @orders.sum(:item_total)
        @adjustment_total = @orders.sum(:adjustment_total)
        @sales_total = @orders.sum(:total)

        respond_with
      end

      private
      def load_data

      end

    end
  end
end
