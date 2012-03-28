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
        params[:search] = {} unless params[:search]

        if params[:search][:created_at_greater_than].blank?
          params[:search][:created_at_greater_than] = Time.zone.now.beginning_of_month
        else
          params[:search][:created_at_greater_than] = Time.zone.parse(params[:search][:created_at_greater_than]).beginning_of_day rescue Time.zone.now.beginning_of_month
        end

        if params[:search] && !params[:search][:created_at_less_than].blank?
          params[:search][:created_at_less_than] =
                                          Time.zone.parse(params[:search][:created_at_less_than]).end_of_day rescue ""
        end

        if params[:search].delete(:completed_at_is_not_null) == "1"
          params[:search][:completed_at_is_not_null] = true
        else
          params[:search][:completed_at_is_not_null] = false
        end

        params[:search][:meta_sort] ||= "created_at.desc"

        @search = Order.complete.metasearch(params[:search])
        @orders = @search
        @item_total = @search.sum(:item_total)
        @adjustment_total = @search.sum(:adjustment_total)
        @sales_total = @search.sum(:total)

        respond_with
      end

      private
      def load_data

      end

    end
  end
end
