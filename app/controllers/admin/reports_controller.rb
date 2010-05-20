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
    @search.checkout_complete = true
    #set order by to default or form result
    @search.order ||= "descend_by_created_at"

    @orders = @search.find(:all)

    @item_total = @search.sum(:item_total)
    @charge_total = @search.sum(:adjustment_total)
    @credit_total = @search.sum(:credit_total)
    @sales_total = @search.sum(:total)
  end

  private
  def load_data

  end

end
