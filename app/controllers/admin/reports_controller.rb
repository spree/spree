class Admin::ReportsController < Admin::BaseController
  before_filter :load_data  
  
  AVAILABLE_REPORTS = {
    :sales_total => {:name => "Sales Total", :description => "Sales Total For All Orders"}
  }

  def index
    @reports = AVAILABLE_REPORTS
  end
  
  def sales_total

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
