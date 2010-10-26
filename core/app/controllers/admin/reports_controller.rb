class Admin::ReportsController < Admin::BaseController
  before_filter :load_data

  AVAILABLE_REPORTS = {
    :sales_total => {:name => "Sales Total", :description => "Sales Total For All Orders"}
  }

  def index
    @reports = AVAILABLE_REPORTS
  end

  def sales_total
    params[:search] = {} unless params[:search]

    if params[:search][:created_at_after].blank?
      params[:search][:created_at_after] = Time.zone.now.beginning_of_month
    else
      params[:search][:created_at_after] = Time.zone.parse(params[:search][:created_at_after]).beginning_of_day rescue Time.zone.now.beginning_of_month
    end

    if params[:search] && !params[:search][:created_at_before].blank?
      params[:search][:created_at_before] = Time.zone.parse(params[:search][:created_at_before]).end_of_day rescue ""
    end


    @search = Order.searchlogic(params[:search])
    @search.completed_at_not_null
    #set order by to default or form result
    @search.order ||= "descend_by_created_at"

    @orders = @search.do_search

    @item_total = @search.do_search.sum(:item_total)
    @adjustment_total = @search.do_search.sum(:adjustment_total)
    @sales_total = @search.do_search.sum(:total)
  end

  private
  def load_data

  end

end
